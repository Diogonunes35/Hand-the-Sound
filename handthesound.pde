/*
   * handTheSound
 *
 * Arduino controls:
 *   roll   -> horizontal tilt
 *   pitch  -> vertical tilt
 *   button1 and button2 -> buttons value
 *   flex   -> flex sensor
 */

import processing.sound.*;
import processing.serial.*;


// ── Serial ────────────────────────────────────────────────────────────────────

Serial port;
String serialData = "";
float roll, pitch, button1, button2, flex;


// ── 3D model ──────────────────────────────────────────────────────────────────

PShape handModel;


// ── Hand rotation ─────────────────────────────────────────────────────────────

float smoothRotH = 0; // smoothed horizontal rotation
float smoothRotV = 0; // smoothed vertical rotation


// ── Raw sensor values ─────────────────────────────────────────────────────────

float sensorH = 0; // roll
float sensorV = 0; // pitch
float sensorFlex = 0; // flex

// Previous frame sensor values
float prevSensorH = 0;
float prevSensorV = 0;
float prevButton1 = 0;
float prevButton2 = 0;
boolean button1Pressed = false;
boolean button2Pressed = false;


// ── Mapped effect values ──────────────────────────────────────────────────────
// [6 sounds][2 effects]: index 0 = Pitch, index 1 = Reverb

float[][] soundEffects = new float[6][2];


// ── SFX ───────────────────────────────────────────────────────────────────────

float TILT_THRESHOLD = 30.0;

String[] SFX_MOVEMENTS = {
  "Tilt Left",
  "Tilt Right",
  "Tilt Back",
  "Tilt Forward",
  "Button 1 Hold",
  "Button 2 Hold",
  "Button 1 Press",
  "Button 2 Press"
};
int sfx1Movement = -1;
boolean sfx1Active = false;
int sfx2Movement = -1;
boolean sfx2Active = false;
int sfx3Movement = -1;
boolean sfx3Active = false;
int sfx4Movement = -1;
boolean sfx4Active = false;
int sfx5Movement = -1;
boolean sfx5Active = false;

class SFX {
  SoundFile audio;
  boolean[] chord;
  boolean isAudio = false;
  boolean isChord = false;
  boolean isPlaying = false;
}

SoundFile mainSound;
SFX[] sfx = new SFX[5];
SinOsc[][] chordOsc = new SinOsc[5][13];
Reverb reverb;

boolean mainLoaded = false;
boolean[] sfxLoaded = { false, false, false, false, false };
boolean playing = false;


// ── Gravador de composição ────────────────────────────────────────────────────

class SnapshotSensor {
  float rolar;
  float inclinar;
  float flexao;
  float botao1;
  float botao2;
  boolean[] sfxAtivo;

  SnapshotSensor(float r, float i, float f, float b1, float b2, boolean[] sfx) {
    rolar    = r;
    inclinar = i;
    flexao   = f;
    botao1   = b1;
    botao2   = b2;
    sfxAtivo = new boolean[sfx.length];
    for (int x = 0; x < sfx.length; x++) sfxAtivo[x] = sfx[x];
  }
}

class SlotGravacao {
  ArrayList<SnapshotSensor> gravacao;
  boolean estaAGravar     = false;
  boolean estaAReproduzir = false;
  boolean temGravacao     = false;
  int frameAtual          = 0;
  float pausaSegundos     = 4.0;
  float temporizador      = 0;

  SlotGravacao() {
    gravacao = new ArrayList<SnapshotSensor>();
  }
}

SlotGravacao[] slotsGravacao = new SlotGravacao[3];

int GRAV_TAB_X, GRAV_TAB_Y;
int GRAV_LINHA_H  = 44;
int GRAV_LINHA_G  = 6;
int GRAV_COL_REC  = 100;
int GRAV_COL_LOOP = 100;
int GRAV_COL_SEG  = 110;
int GRAV_COL_DEL  = 50;


// ── Calibration ───────────────────────────────────────────────────────────────

int appState = 0;
String[] calibLog = new String[20];
int calibLogCount = 0;
boolean calibComplete = false;


// ── Colour palette ────────────────────────────────────────────────────────────

color C_BG = color(13, 10, 46);
color C_PANEL = color(25, 20, 70);
color C_BORDER = color(255, 255, 255, 60);
color C_TEXT = color(255, 255, 255, 200);
color C_ACCENT = color(140, 120, 255);
color C_ORANGE = color(255, 140, 60);
color C_GREEN = color(100, 255, 160);
color C_FLEX = color(255, 180, 80);
color C_LIST_BG = color(18, 14, 58);
color C_LIST_HOV = color(55, 45, 130);
color C_PLAY = color(100, 255, 160);
color C_PAUSE = color(255, 180, 80);
color C_OFF = color(60, 55, 100);
color C_HOVER = color(50, 40, 110);
color C_ACTIVE = color(80, 200, 120);


// ── Font / window ─────────────────────────────────────────────────────────────

PFont font;
PFont calibFont;
int W, H;


// ── Mapping table options ─────────────────────────────────────────────────────

// Effects: 0 = Pitch, 1 = Reverb  (Bass and Flex removed)
String[] EFFECTS = {
  "Pitch",
  "Reverb"
};
String[] MOVEMENTS = {
  "Hand Tilt (horizontal)",
  "Hand Tilt (vertical)",
  "Button 1",
  "Button 2",
  "Flex"
};
String[] SOUNDS = {
  "Main",
  "SFX 1",
  "SFX 2",
  "SFX 3",
  "SFX 4",
  "SFX 5"
};


// ── Table rows ────────────────────────────────────────────────────────────────

int MAX_ROWS = 8;
int numRows = 1;
int[][] rows = new int[MAX_ROWS][3];


// ── Dropdown state ────────────────────────────────────────────────────────────

int dropOpen = 0;
int dropRow = -1;
int dropHover = -1;
int dropContext = 0;


// ── Table layout constants ────────────────────────────────────────────────────

int tableX, tableY;
int COL_SOUND = 120;
int COL_EFFECT = 160;
int COL_MOVEMENT = 230;
int COL_VALUE = 140;
int ROW_H = 56;
int ROW_GAP = 8;
int PILL_RADIUS = 10;
int ITEM_H = 32;


// ── Sound panel button positions ──────────────────────────────────────────────

int PLAY_X = 50, PLAY_Y = 0, PLAY_W = 120, PLAY_H = 48;
int IMP_W = 160, IMP_H = 40;
int IMP_MAIN_X, IMP_MAIN_Y;
int IMP_SFX1_X, IMP_SFX1_Y;
int IMP_SFX2_X, IMP_SFX2_Y;
int IMP_SFX3_X, IMP_SFX3_Y;
int IMP_SFX4_X, IMP_SFX4_Y;
int IMP_SFX5_X, IMP_SFX5_Y;

int SFX_MOV_W = 160, SFX_MOV_H = 40;
int SFX1_MOV_X, SFX1_MOV_Y;
int SFX2_MOV_X, SFX2_MOV_Y;
int SFX3_MOV_X, SFX3_MOV_Y;
int SFX4_MOV_X, SFX4_MOV_Y;
int SFX5_MOV_X, SFX5_MOV_Y;


// ── Piano ─────────────────────────────────────────────────────────────────────

float[] PIANO_FREQ = {
  261.63, 277.18, 293.66, 311.13, 329.63, 349.23,
  369.99, 392.00, 415.30, 440.00, 466.16, 493.88, 523.25
};

String[] PIANO_LABELS = {
  "C", "C#", "D", "D#", "E", "F",
  "F#", "G", "G#", "A", "A#", "B", "C"
};

SinOsc[] pianoOsc;
boolean[] pianoActive;

int pianoX = 450, pianoY;
int PIANO_H = 90, KEY_W = 45;
int stopX, stopY, STOP_W = 120, STOP_H = 40;


// ── Setup ─────────────────────────────────────────────────────────────────────

void setup() {
  size(1600, 1000, P3D);
  smooth(8);

  port = new Serial(this, "COM6", 9600);
  port.bufferUntil('\n');

  W = width;
  H = height;

  tableX = W/2+75;
  tableY = H / 6;

  PLAY_Y = H - 80;
  IMP_MAIN_X = 50;
  IMP_MAIN_Y = H - 150;
  IMP_SFX1_X = 50;
  IMP_SFX1_Y = H - 200;
  IMP_SFX2_X = 50;
  IMP_SFX2_Y = H - 250;
  IMP_SFX3_X = 50;
  IMP_SFX3_Y = H - 300;
  IMP_SFX4_X = 50;
  IMP_SFX4_Y = H - 350;
  IMP_SFX5_X = 50;
  IMP_SFX5_Y = H - 400;

  SFX1_MOV_X = IMP_SFX1_X + IMP_W + 10;
  SFX1_MOV_Y = IMP_SFX1_Y;
  SFX2_MOV_X = IMP_SFX2_X + IMP_W + 10;
  SFX2_MOV_Y = IMP_SFX2_Y;
  SFX3_MOV_X = IMP_SFX3_X + IMP_W + 10;
  SFX3_MOV_Y = IMP_SFX3_Y;
  SFX4_MOV_X = IMP_SFX4_X + IMP_W + 10;
  SFX4_MOV_Y = IMP_SFX4_Y;
  SFX5_MOV_X = IMP_SFX5_X + IMP_W + 10;
  SFX5_MOV_Y = IMP_SFX5_Y;

  for (int i = 0; i < MAX_ROWS; i++) {
    rows[i][0] = -1;
    rows[i][1] = -1;
    rows[i][2] = -1;
  }

  try {
    handModel = loadShape("maod.obj");
    if (handModel != null) handModel.disableStyle();
  }
  catch (Exception e) {
    handModel = null;
  }

  reverb = new Reverb(this);
  font = createFont("Helvetica Neue", 14, true);
  textFont(font);
  calibFont = createFont("Courier New", 16, true);

  pianoY = H - 120;
  stopX = pianoX + PIANO_FREQ.length * KEY_W + 20;
  stopY = pianoY + 25;

  pianoOsc = new SinOsc[PIANO_FREQ.length];
  pianoActive = new boolean[PIANO_FREQ.length];
  for (int i = 0; i < PIANO_FREQ.length; i++) {
    pianoOsc[i] = new SinOsc(this);
    pianoOsc[i].freq(PIANO_FREQ[i]);
    pianoOsc[i].amp(0.08);
    pianoActive[i] = false;
  }

  for (int i = 0; i < 5; i++) {
    sfx[i] = new SFX();
    sfx[i].chord = new boolean[PIANO_FREQ.length];
  }

  for (int s = 0; s < 5; s++) {
    for (int i = 0; i < PIANO_FREQ.length; i++) {
      chordOsc[s][i] = new SinOsc(this);
      chordOsc[s][i].freq(PIANO_FREQ[i]);
      chordOsc[s][i].amp(0.1);
    }
  }

  for (int i = 0; i < 3; i++) slotsGravacao[i] = new SlotGravacao();

  GRAV_TAB_X = W - 450;
  GRAV_TAB_Y = H / 2 + H / 8;
}


// ── Draw ──────────────────────────────────────────────────────────────────────

void draw() {
  background(C_BG);
  hint(DISABLE_DEPTH_TEST);

  if (appState == 0) {
    drawCalibration();
  } else {
    updateSensors();
    applyMappings();
    applyEffects();
    updateSFX();
    atualizarGravacoes();
    drawNavbar();
    drawHand3D();
    drawSensorBars();
    drawStatusBar();
    drawSoundPanel();
    drawPiano();
    drawTable();
    drawAddRowButton();
    desenharTabelaGravacao();
    if (dropOpen != 0) drawDropdown();
  }
  prevButton1 = button1;
  prevButton2 = button2;
}


// ── Calibration ───────────────────────────────────────────────────────────────

void drawCalibration() {
  background(C_BG);

  int panelW = 760;
  int panelH = 430;
  int panelX = W / 2 - panelW / 2;
  int panelY = H / 2 - panelH / 2 + 10;

  noStroke();
  fill(10, 8, 35, 220);
  rect(panelX + 6, panelY + 6, panelW, panelH, 12);
  fill(C_LIST_BG);
  rect(panelX, panelY, panelW, panelH, 12);

  fill(255, 255, 255, 55);
  textFont(font);
  textSize(11);
  textAlign(LEFT, TOP);
  text("Serial output", panelX + 18, panelY + 14);

  String[] fallbackLines = {
    "Waiting for Arduino output..."
  };

  String[] linesToShow = calibLogCount > 0 ? calibLog : fallbackLines;
  int startIndex = calibLogCount > 0 ? max(0, calibLogCount - 18) : 0;
  int lineY = panelY + 46;

  fill(235);
  textFont(calibFont);
  textSize(16);
  for (int i = startIndex; i < linesToShow.length; i++) {
    String line = linesToShow[i];
    if (line == null) line = "";
    text(line, panelX + 24, lineY);
    lineY += 18;
  }
  textFont(font);

  fill(calibComplete ? C_GREEN : C_TEXT);
  textSize(13);
  textAlign(CENTER, CENTER);
  text(calibComplete ? "Calibration complete. Press SPACE to continue." : "", W / 2, panelY + panelH + 26);
}

void finishCalibration() {
  calibComplete = true;
  appState = 1;
}


// ── Sensors ───────────────────────────────────────────────────────────────────

void updateSensors() {
  prevSensorH = sensorH;
  prevSensorV = sensorV;

  sensorH    = constrain(roll, -100, 100);
  sensorV    = constrain(pitch, -100, 100);
  sensorFlex = constrain(flex, -100, 100);

  float targetH = map(sensorH, -100, 100, -PI * 0.6, PI * 0.6);
  float targetV = map(sensorV, -100, 100, -PI * 0.3, PI * 0.3);

  smoothRotH = lerp(smoothRotH, targetH, 0.5);
  smoothRotV = lerp(smoothRotV, targetV, 0.5);
}


// ── Effect mappings ───────────────────────────────────────────────────────────

void applyMappings() {
  for (int s = 0; s < 6; s++) {
    for (int e = 0; e < 2; e++) soundEffects[s][e] = 0;
  }

  for (int i = 0; i < numRows; i++) {
    int soundIdx    = rows[i][0];
    int effectIdx   = rows[i][1];
    int movementIdx = rows[i][2];

    if (soundIdx == -1 || effectIdx == -1 || movementIdx == -1) continue;
    if (effectIdx < 2) soundEffects[soundIdx][effectIdx] = sensorValueFor(movementIdx);
  }
}

float sensorValueFor(int movementIdx) {
  switch (movementIdx) {
  case 0:
    return sensorH;
  case 1:
    return sensorV;
  case 2:
    return button1;
  case 3:
    return button2;
  case 4:
    return sensorFlex;
  default:
    return 0;
  }
}


// ── Audio effects ─────────────────────────────────────────────────────────────

void applyEffects() {
  applyEffectsToSound(mainSound, 0, mainLoaded);

  if (sfxLoaded[0]) {
    if (sfx[0].isAudio && sfx[0].audio != null) applyEffectsToSound(sfx[0].audio, 1, true);
    else if (sfx[0].isChord) applyEffectsToChord(0, 1);
  }
  if (sfxLoaded[1]) {
    if (sfx[1].isAudio && sfx[1].audio != null) applyEffectsToSound(sfx[1].audio, 2, true);
    else if (sfx[1].isChord) applyEffectsToChord(1, 2);
  }
  if (sfxLoaded[2]) {
    if (sfx[2].isAudio && sfx[2].audio != null) applyEffectsToSound(sfx[2].audio, 3, true);
    else if (sfx[2].isChord) applyEffectsToChord(2, 3);
  }
  if (sfxLoaded[3]) {
    if (sfx[3].isAudio && sfx[3].audio != null) applyEffectsToSound(sfx[3].audio, 4, true);
    else if (sfx[3].isChord) applyEffectsToChord(3, 4);
  }
  if (sfxLoaded[4]) {
    if (sfx[4].isAudio && sfx[4].audio != null) applyEffectsToSound(sfx[4].audio, 5, true);
    else if (sfx[4].isChord) applyEffectsToChord(4, 5);
  }
}

void applyEffectsToSound(SoundFile snd, int soundIndex, boolean loaded) {
  if (!loaded || snd == null) return;

  // [0] = Pitch, [1] = Reverb
  float pitchVal  = soundEffects[soundIndex][0];
  float reverbAmt = soundEffects[soundIndex][1];

  snd.rate(map(pitchVal, -100, 100, 0.25, 2.0));

  float rev       = constrain(reverbAmt, -100, 100);
  float revVolume = map(rev, -100, 100, 0.25, 1.5);
  snd.amp(0.7 * revVolume);

  reverb.room(map(rev, -100, 100, 0, 1));
  reverb.wet(map(rev, -100, 100, 0.0, 1.0));
  reverb.damp(map(rev, -100, 100, 1.0, 0.2));
}

void applyEffectsToChord(int chordId, int soundIndex) {
  // [0] = Pitch, [1] = Reverb
  float pitchVal  = soundEffects[soundIndex][0];
  float reverbAmt = soundEffects[soundIndex][1];

  float pitchScale;
  if (pitchVal >= 0) {
    pitchScale = map(pitchVal, 0, 100, 1.0, 2.0);
  } else {
    pitchScale = map(pitchVal, -100, 0, 0.5, 1.0);
  }
  float ampVal = 0.10;
  for (int i = 0; i < PIANO_FREQ.length; i++) {
    chordOsc[chordId][i].freq(PIANO_FREQ[i] * pitchScale);
    chordOsc[chordId][i].amp(ampVal);
  }
  float rev = map(reverbAmt, -100, 100, 0.0, 1.0);
  reverb.room(rev);
  reverb.wet(rev * 0.8);
}


void updateSFX() {
  if (sfxLoaded[0] && sfx1Movement != -1) {
    boolean g = isSFXGestureActive(sfx1Movement);
    if (g && !sfx1Active) {
      startSFX(0);
      sfx1Active = true;
    } else if (!g && sfx1Active) {
      stopSFX(0);
      sfx1Active = false;
    }
  }
  if (sfxLoaded[1] && sfx2Movement != -1) {
    boolean g = isSFXGestureActive(sfx2Movement);
    if (g && !sfx2Active) {
      startSFX(1);
      sfx2Active = true;
    } else if (!g && sfx2Active) {
      stopSFX(1);
      sfx2Active = false;
    }
  }
  if (sfxLoaded[2] && sfx3Movement != -1) {
    boolean g = isSFXGestureActive(sfx3Movement);
    if (g && !sfx3Active) {
      startSFX(2);
      sfx3Active = true;
    } else if (!g && sfx3Active) {
      stopSFX(2);
      sfx3Active = false;
    }
  }
  if (sfxLoaded[3] && sfx4Movement != -1) {
    boolean g = isSFXGestureActive(sfx4Movement);
    if (g && !sfx4Active) {
      startSFX(3);
      sfx4Active = true;
    } else if (!g && sfx4Active) {
      stopSFX(3);
      sfx4Active = false;
    }
  }
  if (sfxLoaded[4] && sfx5Movement != -1) {
    boolean g = isSFXGestureActive(sfx5Movement);
    if (g && !sfx5Active) {
      startSFX(4);
      sfx5Active = true;
    } else if (!g && sfx5Active) {
      stopSFX(4);
      sfx5Active = false;
    }
  }
}

boolean isSFXGestureActive(int movIdx) {
  switch (movIdx) {
  case 0:
    return sensorH < -TILT_THRESHOLD;
  case 1:
    return sensorH > TILT_THRESHOLD;
  case 2:
    return sensorV < -TILT_THRESHOLD;
  case 3:
    return sensorV > TILT_THRESHOLD;
  case 4:
    return button1 == 1;
  case 5:
    return button2 == 1;
  case 6:
    if (button1 == 1 && prevButton1 == 0) {
      button1Pressed = !button1Pressed;
      delay(50);
    }
    return button1Pressed;
  case 7:
    if (button2 == 1 && prevButton2 == 0) {
      button2Pressed = !button2Pressed;
      delay(50);
    }
    return button2Pressed;
  default:
    return false;
  }
}


// ── SFX start / stop helpers ──────────────────────────────────────────────────

void startSFX(int id) {
  SFX s = sfx[id];
  if (s.isAudio && s.audio != null && !s.audio.isPlaying()) s.audio.loop();
  if (s.isChord) {
    for (int i = 0; i < PIANO_FREQ.length; i++) if (s.chord[i]) chordOsc[id][i].play();
  }
  s.isPlaying = true;
}

void stopSFX(int id) {
  SFX s = sfx[id];
  if (s.isAudio && s.audio != null) s.audio.stop();
  if (s.isChord) {
    for (int i = 0; i < PIANO_FREQ.length; i++) chordOsc[id][i].stop();
  }
  s.isPlaying = false;
}


// ── Navbar ────────────────────────────────────────────────────────────────────

void drawNavbar() {
  textSize(22);
  textAlign(LEFT, CENTER);
  fill(255, 255, 255, 180);
  text("hand", 50, 42);
  fill(255);
  text("TheSound", 50 + textWidth("hand"), 42);

  fill(C_TEXT);
  textSize(16);
  textAlign(RIGHT, CENTER);
  text("info", W - 200, 42);
  text("contact us", W - 50, 42);

  fill(255, 255, 255, 55);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("roll -> horizontal  |  pitch -> vertical  |  button -> press  |  flex -> flex sensor", W / 2, 42);
}


// ── 3D hand ───────────────────────────────────────────────────────────────────

void drawHand3D() {
  pushMatrix();
  translate(W * 0.29, H * 0.50 + 40, 0);
  rotateX(PI);
  rotateX(smoothRotV);
  rotateZ(-smoothRotH);
  lights();
  directionalLight(220, 210, 255, -0.4, 0.5, -1);
  ambientLight(60, 50, 90);
  fill(240, 235, 250);
  noStroke();
  scale(20.0);
  shape(handModel, -5, 10);
  popMatrix();
  noLights();
}


// ── Sensor bars ───────────────────────────────────────────────────────────────

void drawSensorBars() {
  int bx = W - 195, by = H - 165, bw = 18, bh = 100;
  drawBar(bx, by, bw, bh, sensorH, "Roll");
  drawBar(bx + 36, by, bw, bh, sensorV, "Pitch");
  drawBar(bx + 72, by, bw, bh, map(button1, 0, 1, -100, 100), "Button 1");
  drawBar(bx + 108, by, bw, bh, map(button2, 0, 1, -100, 100), "Button 2");
  drawBar(bx + 144, by, bw, bh, sensorFlex, "Flex");
}

void drawBar(int x, int y, int bw, int bh, float val, String label) {
  noStroke();
  fill(C_PANEL);
  rect(x, y, bw, bh, bh / 2);
  float norm = map(constrain(val, -100, 100), -100, 100, 0, 1);
  float fillH = bh * norm;
  fill(lerpColor(color(80, 70, 140), val >= 0 ? C_FLEX : C_ORANGE, norm));
  if (fillH > 0) rect(x, y + bh - fillH, bw, fillH, fillH / 2);
  fill(C_TEXT);
  textSize(10);
  textAlign(CENTER, TOP);
  text(label, x + bw / 2, y + bh + 6);
  fill(255, 255, 255, 90);
  textSize(9);
  textAlign(CENTER, BOTTOM);
  text(nf(val, 0, 0), x + bw / 2, y - 6);
}


// ── Status bar ────────────────────────────────────────────────────────────────

void drawStatusBar() {
  noStroke();
  fill(C_GREEN);
  ellipse(W - 210, H - 30, 8, 8);
  fill(255, 255, 255, 160);
  textSize(13);
  textAlign(RIGHT, BOTTOM);
  text("Arduino is connected", W - 50, H - 22);
}


// ── Sound panel ───────────────────────────────────────────────────────────────

void drawSoundPanel() {
  boolean hoverMain = hover(IMP_MAIN_X, IMP_MAIN_Y, IMP_W, IMP_H);
  boolean hoverSfx1 = hover(IMP_SFX1_X, IMP_SFX1_Y, IMP_W, IMP_H);
  boolean hoverSfx2 = hover(IMP_SFX2_X, IMP_SFX2_Y, IMP_W, IMP_H);
  boolean hoverSfx3 = hover(IMP_SFX3_X, IMP_SFX3_Y, IMP_W, IMP_H);
  boolean hoverSfx4 = hover(IMP_SFX4_X, IMP_SFX4_Y, IMP_W, IMP_H);
  boolean hoverSfx5 = hover(IMP_SFX5_X, IMP_SFX5_Y, IMP_W, IMP_H);
  boolean hoverPlay = hover(PLAY_X, PLAY_Y, PLAY_W, PLAY_H);

  drawImportButton(IMP_MAIN_X, IMP_MAIN_Y, IMP_W, IMP_H,
    mainLoaded ? "Main: loaded \u2713" : "Import Main Sound", mainLoaded, hoverMain);

  drawImportButton(IMP_SFX1_X, IMP_SFX1_Y, IMP_W, IMP_H,
    sfxLoaded[0] ? "SFX 1: loaded \u2713" : "Import SFX 1  [G]", sfxLoaded[0], hoverSfx1);
  drawSFXMovementPill(SFX1_MOV_X, SFX1_MOV_Y, SFX_MOV_W, SFX_MOV_H,
    sfx1Movement == -1 ? "Trigger: choose \u25be" : "Trigger: " + SFX_MOVEMENTS[sfx1Movement],
    dropOpen != 0 && dropContext == 4, sfx1Active);

  drawImportButton(IMP_SFX2_X, IMP_SFX2_Y, IMP_W, IMP_H,
    sfxLoaded[1] ? "SFX 2: loaded \u2713" : "Import SFX 2  [H]", sfxLoaded[1], hoverSfx2);
  drawSFXMovementPill(SFX2_MOV_X, SFX2_MOV_Y, SFX_MOV_W, SFX_MOV_H,
    sfx2Movement == -1 ? "Trigger: choose \u25be" : "Trigger: " + SFX_MOVEMENTS[sfx2Movement],
    dropOpen != 0 && dropContext == 5, sfx2Active);

  drawImportButton(IMP_SFX3_X, IMP_SFX3_Y, IMP_W, IMP_H,
    sfxLoaded[2] ? "SFX 3: loaded \u2713" : "Import SFX 3  [J]", sfxLoaded[2], hoverSfx3);
  drawSFXMovementPill(SFX3_MOV_X, SFX3_MOV_Y, SFX_MOV_W, SFX_MOV_H,
    sfx3Movement == -1 ? "Trigger: choose \u25be" : "Trigger: " + SFX_MOVEMENTS[sfx3Movement],
    dropOpen != 0 && dropContext == 6, sfx3Active);

  drawImportButton(IMP_SFX4_X, IMP_SFX4_Y, IMP_W, IMP_H,
    sfxLoaded[3] ? "SFX 4: loaded \u2713" : "Import SFX 4  [K]", sfxLoaded[3], hoverSfx4);
  drawSFXMovementPill(SFX4_MOV_X, SFX4_MOV_Y, SFX_MOV_W, SFX_MOV_H,
    sfx4Movement == -1 ? "Trigger: choose \u25be" : "Trigger: " + SFX_MOVEMENTS[sfx4Movement],
    dropOpen != 0 && dropContext == 7, sfx4Active);

  drawImportButton(IMP_SFX5_X, IMP_SFX5_Y, IMP_W, IMP_H,
    sfxLoaded[4] ? "SFX 5: loaded \u2713" : "Import SFX 5  [L]", sfxLoaded[4], hoverSfx5);
  drawSFXMovementPill(SFX5_MOV_X, SFX5_MOV_Y, SFX_MOV_W, SFX_MOV_H,
    sfx5Movement == -1 ? "Trigger: choose \u25be" : "Trigger: " + SFX_MOVEMENTS[sfx5Movement],
    dropOpen != 0 && dropContext == 8, sfx5Active);

  color btnColor;
  if (!mainLoaded) btnColor = C_OFF;
  else if (playing) btnColor = C_PAUSE;
  else if (hoverPlay) btnColor = C_HOVER;
  else btnColor = C_PLAY;

  noStroke();
  fill(btnColor);
  rect(PLAY_X, PLAY_Y, PLAY_W, PLAY_H, PLAY_H / 2);
  fill(mainLoaded ? color(13, 10, 46) : color(255, 255, 255, 60));
  textSize(14);
  textAlign(CENTER, CENTER);
  text(!mainLoaded ? "Play Main" : playing ? "\u23F8  Pause" : "\u25B6  Play",
    PLAY_X + PLAY_W / 2, PLAY_Y + PLAY_H / 2);

  if (mainLoaded) {
    fill(C_GREEN);
    textSize(10);
    textAlign(LEFT, CENTER);
    text("ready", PLAY_X + PLAY_W + 12, PLAY_Y + PLAY_H / 2);
  }
}

void drawSFXMovementPill(int x, int y, int w, int h,
  String label, boolean dropIsOpen, boolean firing) {
  noStroke();
  if (firing) fill(color(30, 80, 50));
  else if (dropIsOpen) fill(color(55, 45, 130));
  else fill(C_PANEL);
  rect(x, y, w, h, PILL_RADIUS);

  strokeWeight(1);
  stroke(firing ? C_ACTIVE : dropIsOpen ? C_ACCENT : C_BORDER);
  noFill();
  rect(x, y, w, h, PILL_RADIUS);

  noStroke();
  fill(firing ? C_ACTIVE : C_TEXT);
  textSize(11);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);
}

void drawImportButton(int x, int y, int w, int h, String label, boolean loaded, boolean hovered) {
  noStroke();
  fill(loaded ? color(40, 80, 60) : hovered ? C_HOVER : C_PANEL);
  rect(x, y, w, h);
  strokeWeight(1);
  stroke(loaded ? C_GREEN : hovered ? C_ACCENT : C_BORDER);
  noFill();
  rect(x, y, w, h);
  noStroke();
  fill(loaded ? C_GREEN : C_TEXT);
  textSize(11);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);
}

boolean hover(int x, int y, int w, int h) {
  return mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;
}



void loadMain(String path) {
  if (mainSound != null) mainSound.stop();
  mainSound = new SoundFile(this, path);
  reverb.process(mainSound);
  mainLoaded = true;
  playing = false;
}

void loadSFX(int id, String path) {
  if (sfx[id].audio != null) sfx[id].audio.stop();
  sfx[id].audio = new SoundFile(this, path);
  sfx[id].isAudio = true;
  sfx[id].isChord = false;
  sfxLoaded[id] = true;
}

void captureChord(int id) {
  for (int i = 0; i < PIANO_FREQ.length; i++) sfx[id].chord[i] = pianoActive[i];
  sfx[id].isChord = true;
  sfx[id].isAudio = false;
  sfxLoaded[id] = true;
}


// ── Mapping table ─────────────────────────────────────────────────────────────

void drawTable() {
  int tx = tableX, ty = tableY;
  int totalW = COL_SOUND + COL_EFFECT + COL_MOVEMENT + COL_VALUE;

  fill(C_TEXT);
  textSize(12);
  textAlign(CENTER, CENTER);
  text("Sound", tx + COL_SOUND / 2, ty - 22);
  text("Effect", tx + COL_SOUND + COL_EFFECT / 2, ty - 22);
  text("Movement", tx + COL_SOUND + COL_EFFECT + COL_MOVEMENT / 2, ty - 22);
  text("Value", tx + COL_SOUND + COL_EFFECT + COL_MOVEMENT + COL_VALUE / 2, ty - 22);

  stroke(C_BORDER);
  strokeWeight(1);
  line(tx, ty - 8, tx + totalW, ty - 8);
  noStroke();

  for (int i = 0; i < numRows; i++) drawRow(i, tx, ty + i * (ROW_H + ROW_GAP));
}

void drawAddRowButton() {
  int btnY = tableY + numRows * (ROW_H + ROW_GAP) + 8;
  boolean canAdd = numRows < MAX_ROWS;
  float alpha = canAdd ? 200 : 60;

  stroke(red(C_BORDER), green(C_BORDER), blue(C_BORDER), alpha);
  strokeWeight(1);
  noFill();
  rect(tableX, btnY, 130, 44, 22);
  noStroke();
  fill(255, 255, 255, alpha);
  textSize(20);
  textAlign(CENTER, CENTER);
  text("+", tableX + 65, btnY + 22);
}

void drawRow(int idx, int x, int y) {
  int soundIdx    = rows[idx][0];
  int effectIdx   = rows[idx][1];
  int movementIdx = rows[idx][2];
  int gap = 6;

  // SOUND
  boolean soundOpen = (dropOpen != 0 && dropContext == 1 && dropRow == idx);
  noStroke();
  fill(soundOpen ? color(55, 45, 130) : C_PANEL);
  rect(x, y, COL_SOUND - gap, ROW_H, PILL_RADIUS);
  fill(soundIdx == -1 ? color(255, 255, 255, 80) : color(255));
  textAlign(CENTER, CENTER);
  textSize(13);
  text(soundIdx == -1 ? "Choose sound \u25be" : SOUNDS[soundIdx],
    x + (COL_SOUND - gap) / 2, y + ROW_H / 2);

  // EFFECT
  boolean effectOpen = (dropOpen != 0 && dropContext == 2 && dropRow == idx);
  noStroke();
  fill(effectOpen ? color(55, 45, 130) : C_PANEL);
  rect(x + COL_SOUND, y, COL_EFFECT - gap, ROW_H, PILL_RADIUS);
  fill(effectIdx == -1 ? color(255, 255, 255, 80) : color(255));
  text(effectIdx == -1 ? "Choose effect \u25be" : EFFECTS[effectIdx],
    x + COL_SOUND + (COL_EFFECT - gap) / 2, y + ROW_H / 2);

  // MOVEMENT
  boolean movOpen = (dropOpen != 0 && dropContext == 3 && dropRow == idx);
  noStroke();
  fill(movOpen ? color(55, 45, 130) : C_PANEL);
  rect(x + COL_SOUND + COL_EFFECT, y, COL_MOVEMENT - gap, ROW_H, PILL_RADIUS);
  fill(movementIdx == -1 ? color(255, 255, 255, 80) : color(255));
  text(movementIdx == -1 ? "Choose movement \u25be" : MOVEMENTS[movementIdx],
    x + COL_SOUND + COL_EFFECT + (COL_MOVEMENT - gap) / 2, y + ROW_H / 2);

  // VALUE
  boolean rowActive = (effectIdx != -1 && movementIdx != -1);
  float val = rowActive ? sensorValueFor(movementIdx) : 0;

  color valColor = C_PANEL;
  if (rowActive) {
    float t = (val >= 0) ? map(val, 0, 100, 0, 0.6) : map(val, 0, -100, 0, 0.6);
    valColor = lerpColor(C_PANEL, val >= 0 ? C_ACCENT : C_ORANGE, t);
  }
  noStroke();
  fill(valColor);
  rect(x + COL_SOUND + COL_EFFECT + COL_MOVEMENT, y, COL_VALUE - gap, ROW_H, PILL_RADIUS);

  if (rowActive) {
    fill(255);
    textSize(15);
    text((val >= 0 ? "+" : "") + nf(val, 0, 1),
      x + COL_SOUND + COL_EFFECT + COL_MOVEMENT + (COL_VALUE - gap) / 2, y + ROW_H / 2);
  } else {
    fill(255, 255, 255, 35);
    textSize(13);
    text("\u2014",
      x + COL_SOUND + COL_EFFECT + COL_MOVEMENT + (COL_VALUE - gap) / 2, y + ROW_H / 2);
  }
}


// ── Dropdown ──────────────────────────────────────────────────────────────────

String[] activeOptions() {
  if (dropContext == 1) return SOUNDS;
  if (dropContext == 2) return EFFECTS;
  if (dropContext == 3) return MOVEMENTS;
  if (dropContext >= 4 && dropContext <= 8) return SFX_MOVEMENTS;
  return new String[0];
}

int[] dropPosition() {
  if (dropContext == 4) return new int[] { SFX1_MOV_X, SFX1_MOV_Y + SFX_MOV_H + 4, SFX_MOV_W };
  if (dropContext == 5) return new int[] { SFX2_MOV_X, SFX2_MOV_Y + SFX_MOV_H + 4, SFX_MOV_W };
  if (dropContext == 6) return new int[] { SFX3_MOV_X, SFX3_MOV_Y + SFX_MOV_H + 4, SFX_MOV_W };
  if (dropContext == 7) return new int[] { SFX4_MOV_X, SFX4_MOV_Y + SFX_MOV_H + 4, SFX_MOV_W };
  if (dropContext == 8) return new int[] { SFX5_MOV_X, SFX5_MOV_Y + SFX_MOV_H + 4, SFX_MOV_W };

  int rowY = tableY + dropRow * (ROW_H + ROW_GAP);
  int lx, lw;
  if (dropContext == 1) {
    lx = tableX;
    lw = COL_SOUND    - 6;
  } else if (dropContext == 2) {
    lx = tableX + COL_SOUND;
    lw = COL_EFFECT   - 6;
  } else {
    lx = tableX + COL_SOUND + COL_EFFECT;
    lw = COL_MOVEMENT - 6;
  }
  return new int[] { lx, rowY + ROW_H + 4, lw };
}

void drawDropdown() {
  String[] options = activeOptions();
  int[] pos = dropPosition();

  int lx = pos[0];
  int ly = pos[1];
  int lw = pos[2];

  int padding = 6;
  int lh = options.length * ITEM_H + padding * 2;

  noStroke();
  fill(10, 8, 35, 220);
  rect(lx + 4, ly + 4, lw, lh, 10);

  fill(C_LIST_BG);
  rect(lx, ly, lw, lh, 10);

  for (int i = 0; i < options.length; i++) {
    int itemY = ly + padding + i * ITEM_H;
    boolean hov = (i == dropHover);

    if (hov) {
      fill(C_LIST_HOV);
      rect(lx + 4, itemY, lw - 8, ITEM_H, 6);
    }

    fill(hov ? color(255) : C_TEXT);
    textAlign(LEFT, CENTER);
    textSize(12);
    text(options[i], lx + 14, itemY + ITEM_H/2);
  }
}

void updateDropdownHover() {
  if (dropOpen == 0) return;
  String[] options = activeOptions();
  int[] pos = dropPosition();
  int lx = pos[0], ly = pos[1], lw = pos[2];
  dropHover = -1;
  if (mouseX >= lx && mouseX <= lx + lw) {
    int item = (mouseY - ly - 4) / ITEM_H;
    if (item >= 0 && item < options.length) dropHover = item;
  }
}


// ── Piano ─────────────────────────────────────────────────────────────────────

void drawPiano() {
  noStroke();
  fill(C_PANEL);
  rect(pianoX - 10, pianoY - 10, PIANO_FREQ.length * KEY_W + 170, PIANO_H + 20, 12);

  for (int i = 0; i < PIANO_FREQ.length; i++) {
    fill(pianoActive[i] ? C_ACCENT : color(255));
    stroke(0, 40);
    rect(pianoX + i * KEY_W, pianoY, KEY_W - 2, PIANO_H);
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(16);
    text(PIANO_LABELS[i], pianoX + i * KEY_W + (KEY_W - 2) / 2, pianoY + PIANO_H - 18);
  }

  noStroke();
  fill(C_ORANGE);
  rect(stopX, stopY, STOP_W, STOP_H, 10);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(14);
  text("STOP ALL", stopX + STOP_W / 2, stopY + STOP_H / 2);
}


// ── Mouse events ──────────────────────────────────────────────────────────────

void mousePressed() {
  if (appState == 0) return;

  tratarCliqueGravacao();

  if (hover(stopX, stopY, STOP_W, STOP_H)) {
    for (int i = 0; i < pianoOsc.length; i++) {
      pianoOsc[i].stop();
      pianoActive[i] = false;
    }
    return;
  }

  for (int i = 0; i < PIANO_FREQ.length; i++) {
    int kx = pianoX + i * KEY_W;
    if (mouseX >= kx && mouseX <= kx + KEY_W && mouseY >= pianoY && mouseY <= pianoY + PIANO_H) {
      if (pianoActive[i]) {
        pianoOsc[i].stop();
        pianoActive[i] = false;
      } else {
        pianoOsc[i].play();
        pianoActive[i] = true;
      }
      return;
    }
  }

  if (dropOpen != 0) {
    String[] options = activeOptions();
    int[] pos = dropPosition();
    int lx = pos[0], ly = pos[1], lw = pos[2];
    int lh = options.length * ITEM_H + 8;

    if (mouseX >= lx && mouseX <= lx + lw && mouseY >= ly && mouseY <= ly + lh) {
      int clicked = (mouseY - ly - 4) / ITEM_H;
      if (clicked >= 0 && clicked < options.length) {
        if      (dropContext == 1) rows[dropRow][0] = clicked;
        else if (dropContext == 2) rows[dropRow][1] = clicked;
        else if (dropContext == 3) rows[dropRow][2] = clicked;
        else if (dropContext == 4) {
          sfx1Movement = clicked;
          sfx1Active = false;
        } else if (dropContext == 5) {
          sfx2Movement = clicked;
          sfx2Active = false;
        } else if (dropContext == 6) {
          sfx3Movement = clicked;
          sfx3Active = false;
        } else if (dropContext == 7) {
          sfx4Movement = clicked;
          sfx4Active = false;
        } else if (dropContext == 8) {
          sfx5Movement = clicked;
          sfx5Active = false;
        }
      }
    }
    dropOpen = 0;
    dropRow = -1;
    dropHover = -1;
    dropContext = 0;
    return;
  }

  if (hover(SFX1_MOV_X, SFX1_MOV_Y, SFX_MOV_W, SFX_MOV_H)) {
    dropOpen = 1;
    dropContext = 4;
    dropHover = -1;
    return;
  }
  if (hover(SFX2_MOV_X, SFX2_MOV_Y, SFX_MOV_W, SFX_MOV_H)) {
    dropOpen = 1;
    dropContext = 5;
    dropHover = -1;
    return;
  }
  if (hover(SFX3_MOV_X, SFX3_MOV_Y, SFX_MOV_W, SFX_MOV_H)) {
    dropOpen = 1;
    dropContext = 6;
    dropHover = -1;
    return;
  }
  if (hover(SFX4_MOV_X, SFX4_MOV_Y, SFX_MOV_W, SFX_MOV_H)) {
    dropOpen = 1;
    dropContext = 7;
    dropHover = -1;
    return;
  }
  if (hover(SFX5_MOV_X, SFX5_MOV_Y, SFX_MOV_W, SFX_MOV_H)) {
    dropOpen = 1;
    dropContext = 8;
    dropHover = -1;
    return;
  }

  if (hover(PLAY_X, PLAY_Y, PLAY_W, PLAY_H) && mainLoaded) {
    if (playing) {
      mainSound.stop();
      playing = false;
    } else {
      mainSound.loop();
      playing = true;
    }
    return;
  }

  if (hover(IMP_MAIN_X, IMP_MAIN_Y, IMP_W, IMP_H)) {
    selectInput("Escolhe o som principal", "mainFileSelected");
    return;
  }
  if (hover(IMP_SFX1_X, IMP_SFX1_Y, IMP_W, IMP_H)) {
    selectInput("Escolhe SFX 1", "sfx0FileSelected");
    return;
  }
  if (hover(IMP_SFX2_X, IMP_SFX2_Y, IMP_W, IMP_H)) {
    selectInput("Escolhe SFX 2", "sfx1FileSelected");
    return;
  }
  if (hover(IMP_SFX3_X, IMP_SFX3_Y, IMP_W, IMP_H)) {
    selectInput("Escolhe SFX 3", "sfx2FileSelected");
    return;
  }
  if (hover(IMP_SFX4_X, IMP_SFX4_Y, IMP_W, IMP_H)) {
    selectInput("Escolhe SFX 4", "sfx3FileSelected");
    return;
  }
  if (hover(IMP_SFX5_X, IMP_SFX5_Y, IMP_W, IMP_H)) {
    selectInput("Escolhe SFX 5", "sfx4FileSelected");
    return;
  }

  for (int i = 0; i < numRows; i++) {
    int rx = tableX;
    int ry = tableY + i * (ROW_H + ROW_GAP);
    if (mouseX >= rx && mouseX <= rx + COL_SOUND - 6 && mouseY >= ry && mouseY <= ry + ROW_H) {
      dropOpen = 1;
      dropContext = 1;
      dropRow = i;
      dropHover = -1;
      return;
    }
    int ex = rx + COL_SOUND;
    if (mouseX >= ex && mouseX <= ex + COL_EFFECT - 6 && mouseY >= ry && mouseY <= ry + ROW_H) {
      dropOpen = 1;
      dropContext = 2;
      dropRow = i;
      dropHover = -1;
      return;
    }
    int mx = rx + COL_SOUND + COL_EFFECT;
    if (mouseX >= mx && mouseX <= mx + COL_MOVEMENT - 6 && mouseY >= ry && mouseY <= ry + ROW_H) {
      dropOpen = 1;
      dropContext = 3;
      dropRow = i;
      dropHover = -1;
      return;
    }
  }

  int btnY = tableY + numRows * (ROW_H + ROW_GAP) + 8;
  if (mouseX >= tableX && mouseX <= tableX + 130 && mouseY >= btnY && mouseY <= btnY + 44 && numRows < MAX_ROWS) {
    numRows++;
  }
}

void mouseMoved() {
  updateDropdownHover();
}
void mouseDragged() {
  updateDropdownHover();
}


// ── Keyboard events ───────────────────────────────────────────────────────────

void keyPressed() {
  if (appState == 0 && key == ' ') {
    finishCalibration();
    return;
  }
  if (key == 'r' || key == 'R') {
    smoothRotH = 0;
    smoothRotV = 0;
  }
  if (key == 'g' || key == 'G') captureChord(0);
  if (key == 'h' || key == 'H') captureChord(1);
  if (key == 'j' || key == 'J') captureChord(2);
  if (key == 'k' || key == 'K') captureChord(3);
  if (key == 'l' || key == 'L') captureChord(4);
  if (keyCode == ESC) {
    dropOpen = 0;
    dropRow = -1;
    dropContext = 0;
    key = 0;
  }
}

void keyReleased() {
}


// ── Serial event ──────────────────────────────────────────────────────────────

void serialEvent(Serial p) {
  serialData = p.readStringUntil('\n');
  if (serialData == null) return;
  println(serialData);
  serialData = trim(serialData);
  if (serialData.length() == 0) {
    pushCalibrationLine("");
    return;
  }
  String[] parts = split(serialData, '/');
  if (parts.length != 5) {
    pushCalibrationLine(serialData);
    if (serialData.indexOf("Calibration complete!") != -1) calibComplete = true;
    return;
  }
  try {
    roll    = float(parts[0]);
    pitch   = float(parts[1]);
    button1 = float(parts[2]);
    button2 = float(parts[3]);
    flex    = float(parts[4]);
  }
  catch (Exception ignored) {
  }
}

void pushCalibrationLine(String line) {
  for (int i = 0; i < calibLog.length - 1; i++) {
    calibLog[i] = calibLog[i + 1];
  }
  calibLog[calibLog.length - 1] = line;
  if (calibLogCount < calibLog.length) calibLogCount++;
}


// ══════════════════════════════════════════════════════════════════════════════
// ── SISTEMA DE GRAVAÇÃO DE LOOPS ──────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

void gravarFrameAtual(int id) {
  boolean[] sfxAtivos = {
    sfx[0].isPlaying, sfx[1].isPlaying, sfx[2].isPlaying, sfx[3].isPlaying, sfx[4].isPlaying
  };
  slotsGravacao[id].gravacao.add(new SnapshotSensor(
    sensorH, sensorV, sensorFlex, button1, button2, sfxAtivos));
}

void iniciarGravacao(int id) {
  SlotGravacao s = slotsGravacao[id];
  s.gravacao.clear();
  s.estaAGravar = true;
  s.estaAReproduzir = false;
  s.temGravacao = false;
  s.frameAtual = 0;
}

void pararGravacao(int id) {
  SlotGravacao s = slotsGravacao[id];
  s.estaAGravar = false;
  if (s.gravacao.size() > 0) {
    s.temGravacao = true;
    s.frameAtual = 0;
    s.temporizador = 0;
  }
}

void toggleLoop(int id) {
  SlotGravacao s = slotsGravacao[id];
  if (!s.temGravacao) return;
  s.estaAReproduzir = !s.estaAReproduzir;
  if (s.estaAReproduzir) {
    s.frameAtual = 0;
    s.temporizador = 0;
    // Reset transition tracker so first frame fires correctly
    for (int i = 0; i < 5; i++) prevSnapSfxAtivo[id][i] = false;
  } else {
    // Stopping loop: stop any SFX it was driving
    for (int i = 0; i < 5; i++) {
      if (prevSnapSfxAtivo[id][i]) {
        stopSFX(i);
        prevSnapSfxAtivo[id][i] = false;
      }
    }
  }
}

void apagarGravacao(int id) {
  SlotGravacao s = slotsGravacao[id];
  // Stop any SFX the loop was driving before clearing
  for (int i = 0; i < 5; i++) {
    if (prevSnapSfxAtivo[id][i]) {
      stopSFX(i);
      prevSnapSfxAtivo[id][i] = false;
    }
  }
  s.gravacao.clear();
  s.estaAGravar = false;
  s.estaAReproduzir = false;
  s.temGravacao = false;
  s.frameAtual = 0;
  s.temporizador = 0;
}

// Previous snapshot state per slot, to detect transitions and avoid re-triggering every frame
boolean[][] prevSnapSfxAtivo = new boolean[3][5];

void aplicarSnapshot(SnapshotSensor snap, int slotId) {
  float rollReal   = sensorH, pitchReal = sensorV, flexReal = sensorFlex;
  float btn1Real   = button1, btn2Real  = button2;

  sensorH    = snap.rolar;
  sensorV    = snap.inclinar;
  sensorFlex = snap.flexao;
  button1    = snap.botao1;
  button2    = snap.botao2;

  applyMappings();
  applyEffects();

  sensorH    = rollReal;
  sensorV    = pitchReal;
  sensorFlex = flexReal;
  button1    = btn1Real;
  button2    = btn2Real;

  for (int i = 0; i < 5; i++) {
    boolean wasActive = prevSnapSfxAtivo[slotId][i];
    boolean nowActive = snap.sfxAtivo[i];
    if (nowActive && !wasActive) {
      startSFX(i);
    } else if (!nowActive && wasActive) {
      stopSFX(i);
    }
    prevSnapSfxAtivo[slotId][i] = nowActive;
  }
}

void atualizarGravacoes() {
  for (int id = 0; id < 3; id++) {
    SlotGravacao s = slotsGravacao[id];
    if (s.estaAGravar) gravarFrameAtual(id);
    if (s.estaAReproduzir && s.temGravacao && s.gravacao.size() > 0) {
      if (s.frameAtual < s.gravacao.size()) {
        aplicarSnapshot(s.gravacao.get(s.frameAtual), id);
        s.frameAtual++;
      } else {
        // Loop gap: stop any SFX that were playing at end of recording
        for (int i = 0; i < 5; i++) {
          if (prevSnapSfxAtivo[id][i]) {
            stopSFX(i);
            prevSnapSfxAtivo[id][i] = false;
          }
        }
        s.temporizador += 1.0 / frameRate;
        if (s.temporizador >= s.pausaSegundos) {
          s.frameAtual = 0;
          s.temporizador = 0;
        }
      }
    }
  }
}

void desenharTabelaGravacao() {
  int tx = GRAV_TAB_X, ty = GRAV_TAB_Y;
  int totalW = GRAV_COL_REC + GRAV_COL_LOOP + GRAV_COL_SEG + GRAV_COL_DEL + 20;

  fill(C_TEXT);
  textSize(13);
  textAlign(LEFT, CENTER);

  textSize(11);
  textAlign(CENTER, CENTER);
  fill(C_TEXT);
  text("Record", tx + GRAV_COL_REC / 2, ty - 10);
  text("Loop", tx + GRAV_COL_REC + GRAV_COL_LOOP / 2, ty - 10);
  text("Every X sec", tx + GRAV_COL_REC + GRAV_COL_LOOP + GRAV_COL_SEG / 2, ty - 10);
  text("Del", tx + GRAV_COL_REC + GRAV_COL_LOOP + GRAV_COL_SEG + GRAV_COL_DEL / 2, ty - 10);

  stroke(C_BORDER);
  strokeWeight(1);
  line(tx, ty - 2, tx + totalW, ty - 2);
  noStroke();

  for (int i = 0; i < 3; i++) {
    desenharLinhaGravacao(i, tx, ty + i * (GRAV_LINHA_H + GRAV_LINHA_G));
  }
}

void desenharLinhaGravacao(int id, int x, int y) {
  SlotGravacao s = slotsGravacao[id];

  int cx = x;

  // Record / Stop
  int bw = GRAV_COL_REC - 8;
  boolean hovRec = hover(cx, y, bw, GRAV_LINHA_H);
  noStroke();
  fill(s.estaAGravar ? color(200, 50, 50) : hovRec ? C_HOVER : C_PANEL);
  rect(cx, y, bw, GRAV_LINHA_H, 8);
  stroke(s.estaAGravar ? color(255, 80, 80) : hovRec ? C_ACCENT : C_BORDER);
  strokeWeight(1);
  noFill();
  rect(cx, y, bw, GRAV_LINHA_H, 8);
  noStroke();
  fill(s.estaAGravar ? color(255) : C_TEXT);
  textSize(11);
  textAlign(CENTER, CENTER);
  text(s.estaAGravar ? "\u25a0 Stop" : "\u25cf Rec", cx + bw / 2, y + GRAV_LINHA_H / 2);
  cx += GRAV_COL_REC;

  // Loop
  int lw = GRAV_COL_LOOP - 8;
  boolean hovLoop = hover(cx, y, lw, GRAV_LINHA_H);
  noStroke();
  fill(!s.temGravacao ? C_OFF : s.estaAReproduzir ? color(30, 80, 50) : hovLoop ? C_HOVER : C_PANEL);
  rect(cx, y, lw, GRAV_LINHA_H, 8);
  stroke(s.estaAReproduzir ? C_GREEN : hovLoop && s.temGravacao ? C_ACCENT : C_BORDER);
  strokeWeight(1);
  noFill();
  rect(cx, y, lw, GRAV_LINHA_H, 8);
  noStroke();
  fill(s.temGravacao ? (s.estaAReproduzir ? C_GREEN : C_TEXT) : color(255, 255, 255, 60));
  textSize(11);
  textAlign(CENTER, CENTER);
  text(s.estaAReproduzir ? "\u23f8 Pause" : "\u25b6 Loop", cx + lw / 2, y + GRAV_LINHA_H / 2);
  cx += GRAV_COL_LOOP;

  // Every X sec
  int sw = GRAV_COL_SEG - 8;
  int btnArrowW = 26;
  boolean hovMenos = hover(cx, y + 4, btnArrowW, GRAV_LINHA_H - 8);
  noStroke();
  fill(hovMenos ? C_HOVER : C_PANEL);
  rect(cx, y + 4, btnArrowW, GRAV_LINHA_H - 8, 6);
  stroke(C_BORDER);
  strokeWeight(1);
  noFill();
  rect(cx, y + 4, btnArrowW, GRAV_LINHA_H - 8, 6);
  noStroke();
  fill(C_TEXT);
  textSize(14);
  textAlign(CENTER, CENTER);
  text("-", cx + btnArrowW / 2, y + GRAV_LINHA_H / 2);
  fill(C_TEXT);
  textSize(11);
  text(nf(s.pausaSegundos, 0, 1) + "s", cx + sw / 2, y + GRAV_LINHA_H / 2);
  int maisCx = cx + sw - btnArrowW;
  boolean hovMais = hover(maisCx, y + 4, btnArrowW, GRAV_LINHA_H - 8);
  noStroke();
  fill(hovMais ? C_HOVER : C_PANEL);
  rect(maisCx, y + 4, btnArrowW, GRAV_LINHA_H - 8, 6);
  stroke(C_BORDER);
  strokeWeight(1);
  noFill();
  rect(maisCx, y + 4, btnArrowW, GRAV_LINHA_H - 8, 6);
  noStroke();
  fill(C_TEXT);
  textSize(14);
  textAlign(CENTER, CENTER);
  text("+", maisCx + btnArrowW / 2, y + GRAV_LINHA_H / 2);
  cx += GRAV_COL_SEG;

  // Delete
  int dw = GRAV_COL_DEL - 8;
  boolean hovDel = hover(cx, y, dw, GRAV_LINHA_H);
  boolean podeApagar = s.temGravacao || s.estaAGravar;
  noStroke();
  fill(hovDel && podeApagar ? color(150, 40, 40) :  color(80, 20, 70));
  rect(cx, y, dw, GRAV_LINHA_H, 8);
  stroke(hovDel && podeApagar ? color(255, 80, 80) : C_BORDER);
  strokeWeight(1);
  noFill();
  rect(cx, y, dw, GRAV_LINHA_H, 8);
  noStroke();
  fill(podeApagar ? color(255, 100, 100) : color(255, 255, 255, 40));
  textSize(13);
  textAlign(CENTER, CENTER);
  text("\u2715", cx + dw / 2, y + GRAV_LINHA_H / 2);
}

void tratarCliqueGravacao() {
  int tx = GRAV_TAB_X, ty = GRAV_TAB_Y;

  for (int id = 0; id < 3; id++) {
    SlotGravacao s = slotsGravacao[id];
    int ly = ty + id * (GRAV_LINHA_H + GRAV_LINHA_G);
    int cx = tx;

    int bw = GRAV_COL_REC - 8;
    if (hover(cx, ly, bw, GRAV_LINHA_H)) {
      if (s.estaAGravar) pararGravacao(id);
      else iniciarGravacao(id);
      return;
    }
    cx += GRAV_COL_REC;

    int lw = GRAV_COL_LOOP - 8;
    if (hover(cx, ly, lw, GRAV_LINHA_H) && s.temGravacao) {
      toggleLoop(id);
      return;
    }
    cx += GRAV_COL_LOOP;

    int sw = GRAV_COL_SEG - 8;
    int btnArrowW = 26;
    if (hover(cx, ly + 4, btnArrowW, GRAV_LINHA_H - 8)) {
      s.pausaSegundos = max(0.5, s.pausaSegundos - 0.5);
      return;
    }
    int maisCx = cx + sw - btnArrowW;
    if (hover(maisCx, ly + 4, btnArrowW, GRAV_LINHA_H - 8)) {
      s.pausaSegundos = min(30.0, s.pausaSegundos + 0.5);
      return;
    }
    cx += GRAV_COL_SEG;

    int dw = GRAV_COL_DEL - 8;
    if (hover(cx, ly, dw, GRAV_LINHA_H) && (s.temGravacao || s.estaAGravar)) {
      apagarGravacao(id);
      return;
    }
  }
}

void mainFileSelected(File selection) {
  if (selection != null) loadMain(selection.getAbsolutePath());
}
void sfx0FileSelected(File selection) {
  if (selection != null) loadSFX(0, selection.getAbsolutePath());
}
void sfx1FileSelected(File selection) {
  if (selection != null) loadSFX(1, selection.getAbsolutePath());
}
void sfx2FileSelected(File selection) {
  if (selection != null) loadSFX(2, selection.getAbsolutePath());
}
void sfx3FileSelected(File selection) {
  if (selection != null) loadSFX(3, selection.getAbsolutePath());
}
void sfx4FileSelected(File selection) {
  if (selection != null) loadSFX(4, selection.getAbsolutePath());
}
