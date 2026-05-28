import processing.sound.*;
import processing.serial.*;

Serial myPort;

String data="";
float roll, pitch, value, flex;

//sound
SoundFile sound;
Reverb reverb;

boolean soundLoaded = false;

// =========================
// INPUT MODES
// =========================

final int ARDUINO_ROLL = 0;
final int ARDUINO_PITCH = 1;
final int ARDUINO_VALUE = 2;
final int ARDUINO_FLEX = 3;
int pitchMode = ARDUINO_ROLL;
int reverbMode = ARDUINO_PITCH;
int heightMode = ARDUINO_VALUE;
int flexMode = ARDUINO_FLEX;

// =========================
// SLIDERS
// =========================

Slider slider1, slider2, slider3;

void setup() {
  size(1200, 800);
  textFont(createFont("Arial", 16));

  myPort = new Serial(this, "COM6", 9600); // starts the serial communication
  myPort.bufferUntil('\n');

  //println(Serial.list());
  //if (Serial.list().length > 0) {
    //myPort = new Serial(this, Serial.list()[0], 9600);
    //myPort.bufferUntil('\n');
  //}


  slider1 = new Slider(650, 150, 400);
  slider2 = new Slider(650, 280, 400);
  slider3 = new Slider(650, 410, 400);
}

void draw() {
  background(20, 0, 40);

  drawTitle();
  drawLeftPanel();
  drawRightPanel();
  drawBottom();

  // APPLY INPUT MODES
  slider1.value = getInputValue(pitchMode);
  slider2.value = getInputValue(reverbMode);
  slider3.value = getInputValue(flexMode);

  if (soundLoaded && sound != null && reverb != null) {

    float v = slider2.value;

    // REVERB (valores positivos)
    float wet = map(max(v, 0), 0, 100, 0, 1);
    float room = map(max(v, 0), 0, 100, 0.2, 1.0);
    float damp = map(max(v, 0), 0, 100, 0.1, 0.9);

    reverb.wet(wet);
    reverb.room(room);
    reverb.damp(damp);

    // VOLUME (valores negativos)
    float amp = 1.0;
    if (v < 0) {
      amp = map(v, -100, 0, 0.2, 1.0);
    }

    sound.amp(amp);
  }
}

// =========================
// INPUT LOGIC
// =========================

float getInputValue(int mode) {
  if (mode == ARDUINO_ROLL) {
    return map(roll, -90, 90, -100, 100);
  } else if (mode == ARDUINO_PITCH) {
    return map(pitch, -90, 90, -100, 100);
  } else if (mode == ARDUINO_VALUE) {
    return constrain(value, -100, 100);
  } else if (mode == ARDUINO_FLEX) {
    return flex;
  }
  return 0;
}

// Read data from the Serial Port
void serialEvent (Serial myPort) {
  // reads the data from the Serial Port up to the character '.' and puts it into the String variable "data".
  data = myPort.readStringUntil('\n');

  // if you got any bytes other than the linefeed:
  if (data != null) {
    data = trim(data);
    // split the string at "/"
    String items[] = split(data, '/');
    if (items.length > 1) {

      //--- Roll,Pitch in degrees
      roll = float(items[0]);
      pitch = float(items[1]);
      value = float(items[2]);
      flex = float(items[3]);
    }
  }
}


// =========================
// DRAW UI
// =========================

void drawTitle() {
  fill(255);
  textSize(28);
  text("handTheSound", 160, 60);
}

void drawLeftPanel() {
  drawModeBox(160, 120, "Pitch", pitchMode);
  drawModeBox(160, 200, "Reverb", reverbMode);
  drawModeBox(160, 280, "Bass", flexMode);
  drawSoundButton(160, 360);
}

void drawModeBox(int x, int y, String label, int mode) {
  stroke(255);
  noFill();
  rect(x, y, 200, 60, 0, 60, 60, 0);
  rect(x-120, y, 120, 60, 60, 0, 0, 60);

  fill(255);
  text(label, x - 60, y + 35);
  text(getModeName(mode), x + 100, y + 35);
}

String getModeName(int mode) {
  if (mode == ARDUINO_ROLL) return "ROLL";
  if (mode == ARDUINO_PITCH) return "PITCH";
  if (mode == ARDUINO_VALUE) return "BUTTON";
  if (mode == ARDUINO_FLEX) return "FLEX";
  return "NONE";
}

void drawRightPanel() {
  fill(255);

  text("Pitch", 650, 130);
  slider1.display();

  text("Reverb", 650, 260);
  slider2.display();

  text("Height", 650, 390);
  slider3.display();
}

void drawBottom() {
  drawWaveform(300, 550, 400, 60);

  fill(255);
  text("glove is connected", 750, 580);
}

// =========================
// SLIDER
// =========================

class Slider {
  float x, y, w;
  float value;

  Slider(float x, float y, float w) {
    this.x = x;
    this.y = y;
    this.w = w;
  }

  void display() {
    stroke(255);
    line(x, y, x + w, y);

    float pos = map(value, -100, 100, x, x + w);

    fill(255);
    ellipse(pos, y, 14, 14);

    textAlign(CENTER);
    text(int(value), pos, y + 25);
  }
}

//upload sound
void drawSoundButton(int x, int y) {

  String label = soundLoaded ? "SOUND LOADED" : "LOAD SOUND";

  textSize(16);
  float w = textWidth(label) + 30;
  float h = 60;

  boolean hover = mouseX > x && mouseX < x + w &&
    mouseY > y && mouseY < y + h;

  if (hover) fill(255, 255, 255, 40);
  else noFill();

  stroke(255);
  rect(x, y, w, h, 60);

  fill(255);
  textAlign(CENTER, CENTER);
  text(label, x + w/2, y + h/2);
}

void fileSelected(File selection) {
  if (selection == null) return;

  if (sound != null) {
    sound.stop();
  }

  sound = new SoundFile(this, selection.getAbsolutePath());

  reverb = new Reverb(this);
  reverb.process(sound);
  reverb.room(0.8);
  reverb.damp(0.5);

  sound.loop();

  soundLoaded = true;
}

boolean overSoundButton(int x, int y) {
  String label = soundLoaded ? "SOUND LOADED" : "LOAD SOUND";
  float w = textWidth(label) + 30;
  float h = 60;

  return mouseX > x && mouseX < x + w &&
    mouseY > y && mouseY < y + h;
}


// =========================
// WAVEFORM
// =========================

void drawWaveform(int x, int y, int w, int h) {
  stroke(255);
  noFill();
  rect(x, y, w, h, 30);

  for (int i = 0; i < w; i += 5) {
    float n = noise(i * 0.05, frameCount * 0.05);
    float bar = map(n, 0, 1, 5, h - 5);
    line(x + i, y + h/2, x + i, y + h/2 - bar/2);
  }
}

// =========================
// INTERACTION
// =========================

void mousePressed() {
  // cycle modes on click

  if (overBox(50, 120)) pitchMode = (pitchMode + 1) % 4;
  if (overBox(50, 200)) reverbMode = (reverbMode + 1) % 4;
  if (overBox(50, 280)) flexMode = (flexMode + 1) % 4;

  if (overSoundButton(160, 360)) {
    selectInput("Select a sound file", "fileSelected");
  }
}

boolean overBox(int x, int y) {
  return mouseX > x && mouseX < x + 300 &&
    mouseY > y && mouseY < y + 60;
}
