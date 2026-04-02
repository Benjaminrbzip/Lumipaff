#include <Wire.h>
#include <Adafruit_MPR121.h>
#include <Adafruit_NeoPixel.h>

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

Adafruit_MPR121 cap = Adafruit_MPR121();

const int numButtons = 9;
const int numPixelsPerButton = 1;
const int pressThreshold = 500;

// Sorties LED des 9 boutons
const int ledPins[numButtons] = {
  15, // Bouton 1 -> CH0
  33, // Bouton 2 -> CH1
  26, // Bouton 3 -> CH2
  25, // Bouton 4 -> CH3
  16, // Bouton 5 -> CH4
  17, // Bouton 6 -> CH5
  14, // Bouton 7 -> CH6
  32, // Bouton 8 -> CH7
  4   // Bouton 9 -> CH8
};

Adafruit_NeoPixel* pixels[numButtons];

// Couleurs de base pour identifier les boutons
int colorIndex[numButtons] = {
  0, // Rouge
  1, // Vert
  2, // Bleu
  3, // Jaune
  4, // Magenta
  5, // Cyan
  6, // Orange
  7, // Violet
  8  // Blanc
};

bool lastPressed[numButtons] = {false};

// UUIDs BLE
#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define RX_CHAR_UUID        "12345678-1234-1234-1234-1234567890ac"
#define TX_CHAR_UUID        "12345678-1234-1234-1234-1234567890ad"

BLEServer* pServer = nullptr;
BLECharacteristic* pTxCharacteristic = nullptr;
BLECharacteristic* pRxCharacteristic = nullptr;

bool bleClientConnected = false;
bool oldBleClientConnected = false;

bool inCatchMode = false;
uint32_t currentOuterColor = 0;

uint32_t getColor(Adafruit_NeoPixel& pixel, int index) {
  switch (index) {
    case 0: return pixel.Color(255, 0, 0);       // Rouge
    case 1: return pixel.Color(0, 255, 0);       // Vert
    case 2: return pixel.Color(0, 0, 255);       // Bleu
    case 3: return pixel.Color(255, 255, 0);     // Jaune
    case 4: return pixel.Color(255, 0, 255);     // Magenta
    case 5: return pixel.Color(0, 255, 255);     // Cyan
    case 6: return pixel.Color(255, 120, 0);     // Orange
    case 7: return pixel.Color(140, 0, 255);     // Violet
    case 8: return pixel.Color(255, 255, 255);   // Blanc
    default: return pixel.Color(0, 0, 0);        // Eteint
  }
}

const char* colorName(int index) {
  switch (index) {
    case 0: return "Rouge";
    case 1: return "Vert";
    case 2: return "Bleu";
    case 3: return "Jaune";
    case 4: return "Magenta";
    case 5: return "Cyan";
    case 6: return "Orange";
    case 7: return "Violet";
    case 8: return "Blanc";
    default: return "Eteint";
  }
}

void setButtonColor(int buttonIndex, int colorIdx) {
  pixels[buttonIndex]->setPixelColor(0, getColor(*pixels[buttonIndex], colorIdx));
  pixels[buttonIndex]->show();
}

void restoreBaseColors() {
  for (int i = 0; i < numButtons; i++) {
    setButtonColor(i, colorIndex[i]);
  }
}

void setAllBlue() {
  for (int i = 0; i < numButtons; i++) {
    pixels[i]->setPixelColor(0, pixels[i]->Color(0, 0, 255));
    pixels[i]->show();
  }
}

void setAllGreen() {
  for (int i = 0; i < numButtons; i++) {
    pixels[i]->setPixelColor(0, pixels[i]->Color(0, 255, 0));
    pixels[i]->show();
  }
}

void setAllRed() {
  for (int i = 0; i < numButtons; i++) {
    pixels[i]->setPixelColor(0, pixels[i]->Color(255, 0, 0));
    pixels[i]->show();
  }
}

void setCatchMode() {
  inCatchMode = true;
  for (int i = 0; i < numButtons; i++) {
    pixels[i]->setPixelColor(0, pixels[i]->Color(0, 0, 0));
    pixels[i]->show();
  }
  pixels[4]->setPixelColor(0, pixels[4]->Color(255, 80, 0)); // Milieu Orange pur
  pixels[4]->show();
}

void notifyMessage(const String& msg) {
  if (bleClientConnected && pTxCharacteristic != nullptr) {
    pTxCharacteristic->setValue(msg.c_str());
    pTxCharacteristic->notify();
  }
  Serial.println("TX -> " + msg);
}

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    bleClientConnected = true;
    Serial.println("BLE client connecte");
    setAllBlue();
    notifyMessage("CONNECTED");
  }

  void onDisconnect(BLEServer* pServer) override {
    bleClientConnected = false;
    Serial.println("BLE client deconnecte");
  }
};

class MyRxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    String cmd = pCharacteristic->getValue();
    cmd.trim();

    if (cmd.length() == 0) return;

    Serial.print("RX <- ");
    Serial.println(cmd);

    if (cmd == "PING") {
      notifyMessage("PONG");
    } else if (cmd == "BASE") {
      inCatchMode = false;
      restoreBaseColors();
      notifyMessage("OK:BASE");
    } else if (cmd == "BLUE") {
      inCatchMode = false;
      setAllBlue();
      notifyMessage("OK:BLUE");
    } else if (cmd == "GREEN") {
      inCatchMode = false;
      setAllGreen();
      notifyMessage("OK:GREEN");
    } else if (cmd == "RED") {
      inCatchMode = false;
      setAllRed();
      notifyMessage("OK:RED");
    } else if (cmd == "CATCH") {
      setCatchMode();
      notifyMessage("OK:CATCH");
    } else if (cmd.startsWith("IDX:")) {
      if (inCatchMode) {
        int idx = cmd.substring(4).toInt();
        // Définir la couleur globale du tour en fonction de la position du jeu (3,5->Vert, Reste->Rouge)
        if (idx == 3 || idx == 5) currentOuterColor = pixels[0]->Color(0, 255, 0); // Vert
        else currentOuterColor = pixels[0]->Color(255, 0, 0); // Rouge

        // Appliquer cette couleur à TOUT le contour
        for (int i = 0; i < numButtons; i++) {
          if (i != 4) {
            pixels[i]->setPixelColor(0, currentOuterColor);
            pixels[i]->show();
          }
        }
      }
    } else {
      notifyMessage("UNKNOWN_CMD");
    }
  }
};

void setupBLE() {
  BLEDevice::init("LumiPaff-ESP32");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);

  pTxCharacteristic = pService->createCharacteristic(
    TX_CHAR_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pTxCharacteristic->addDescriptor(new BLE2902());

  pRxCharacteristic = pService->createCharacteristic(
    RX_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  pRxCharacteristic->setCallbacks(new MyRxCallbacks());

  pService->start();
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();

  Serial.println("BLE pret");
  Serial.println("Nom BLE : LumiPaff-ESP32");
  Serial.println("Advertising demarre");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Wire.begin(23, 22); // SDA, SCL selon ton shield

  if (!cap.begin(0x5B)) {
    Serial.println("Erreur : MPR121 non detecte sur 0x5B");
    while (1);
  }

  for (int i = 0; i < numButtons; i++) {
    pixels[i] = new Adafruit_NeoPixel(numPixelsPerButton, ledPins[i], NEO_GRB + NEO_KHZ800);
    pixels[i]->begin();
    pixels[i]->setBrightness(50);
    pixels[i]->clear();
    pixels[i]->show();
    setButtonColor(i, colorIndex[i]);
  }

  setupBLE();

  Serial.println("=== Test 9 boutons LED avec MPR121 + BLE ===");
  Serial.print("Seuil d'appui = ");
  Serial.println(pressThreshold);
}

void loop() {
  // Gestion reconnexion advertising après déconnexion
  if (!bleClientConnected && oldBleClientConnected) {
    delay(200);
    pServer->startAdvertising();
    restoreBaseColors();
    Serial.println("Advertising redemarre");
    oldBleClientConnected = bleClientConnected;
  }

  if (bleClientConnected && !oldBleClientConnected) {
    oldBleClientConnected = bleClientConnected;
  }

  for (int i = 0; i < numButtons; i++) {
    uint16_t value = cap.filteredData(i);
    bool isPressed = (value > pressThreshold);

    if (isPressed && !lastPressed[i]) {
      Serial.print("CH");
      Serial.print(i);
      Serial.print(" value=");
      Serial.println(value);

      String msg = "BTN:" + String(i + 1);
      notifyMessage(msg);

      // Effet de brillance si on clique sur un contour pendant le jeu Catch
      if (inCatchMode && i != 4) {
        int contour[] = {0, 1, 2, 5, 8, 7, 6, 3};
        for(int step=0; step<8; step++) {
           int pin = contour[step];
           pixels[pin]->setPixelColor(0, pixels[pin]->Color(255,255,255));
           pixels[pin]->show();
           delay(20);
           pixels[pin]->setPixelColor(0, currentOuterColor); // On remet la vraie couleur au lieu du noir !
           pixels[pin]->show();
        }
      }
    }

    lastPressed[i] = isPressed;
  }

  delay(30);
}