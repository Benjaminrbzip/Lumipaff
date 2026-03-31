#include <Wire.h>
#include <Adafruit_MPR121.h>
#include <Adafruit_NeoPixel.h>
#include "BluetoothSerial.h"

Adafruit_MPR121 cap = Adafruit_MPR121();
BluetoothSerial SerialBT;

const int numButtons = 9;
const int numPixelsPerButton = 1;

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

// Couleur de base unique pour identifier les boutons
int colorIndex[numButtons] = {
  0, // Bouton 1 -> Rouge
  1, // Bouton 2 -> Vert
  2, // Bouton 3 -> Bleu
  3, // Bouton 4 -> Jaune
  4, // Bouton 5 -> Magenta
  5, // Bouton 6 -> Cyan
  6, // Bouton 7 -> Orange
  7, // Bouton 8 -> Violet
  8  // Bouton 9 -> Blanc
};

bool lastPressed[numButtons] = {false};
bool lastBtConnected = false;

// Ajuste ce seuil selon tes mesures
const int pressThreshold = 500;

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

void nextColor(int buttonIndex) {
  colorIndex[buttonIndex]++;
  if (colorIndex[buttonIndex] > 8) {
    colorIndex[buttonIndex] = 0;
  }

  setButtonColor(buttonIndex, colorIndex[buttonIndex]);

  Serial.print("Bouton ");
  Serial.print(buttonIndex + 1);
  Serial.print(" -> Couleur : ");
  Serial.println(colorName(colorIndex[buttonIndex]));
}

void handleBluetoothStatus() {
  bool connected = SerialBT.hasClient();

  if (connected != lastBtConnected) {
    lastBtConnected = connected;

    if (connected) {
      Serial.println("Bluetooth connecte");
      SerialBT.println("ESP32_CONNECTED");
      setAllBlue();
    } else {
      Serial.println("Bluetooth deconnecte");
      restoreBaseColors();
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Wire.begin(23, 22); // SDA, SCL selon ton shield

  if (!cap.begin(0x5B)) {
    Serial.println("Erreur : MPR121 non detecte sur 0x5B");
    while (1);
  }

  if (!SerialBT.begin("LumiPaff-ESP32")) {
    Serial.println("Erreur : echec initialisation Bluetooth");
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

  Serial.println("=== Test 9 boutons LED avec MPR121 + Bluetooth ===");
  Serial.print("Seuil d'appui = ");
  Serial.println(pressThreshold);
  Serial.println("Nom Bluetooth : LumiPaff-ESP32");
  Serial.println("Attente d'une connexion...");
}

void loop() {
  handleBluetoothStatus();

  for (int i = 0; i < numButtons; i++) {
    uint16_t value = cap.filteredData(i);
    bool isPressed = (value > pressThreshold);

    // Détection sur front montant
    if (isPressed && !lastPressed[i]) {
      nextColor(i);

      Serial.print("CH");
      Serial.print(i);
      Serial.print(" value=");
      Serial.println(value);

      if (SerialBT.hasClient()) {
        SerialBT.print("BTN:");
        SerialBT.println(i + 1);
      }
    }

    lastPressed[i] = isPressed;
  }

  delay(30);
}