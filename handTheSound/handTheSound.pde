/*
 * handTheSound
 *
 * Controlos via Arduino:
 *   roll   -> inclinacao horizontal
 *   pitch  -> inclinacao vertical
 *   button -> valor do botao
 *   flex   -> sensor flexivel
 */

import processing.sound.*;
import javax.swing.JFileChooser;
import javax.swing.filechooser.FileNameExtensionFilter;
import java.io.File;
import processing.serial.*;

// Porta Serial /////////////////////////////////////////////////////////////////////////////

Serial myPort;
String data="";
float roll, pitch, button, flex;


// Modelo 3D ///////////////////////////////////////////////////////////////////////////////////

PShape modeloMao; // ficheiro .obj da mao


// Rotacao da mao ///////////////////////////////////////////////////////////////////////////////////

float rotHorSuave = 0; // rotacao horizontal suavizada
float rotVerSuave = 0; // rotacao vertical suavizada

// Sensores (valores brutos, sem som) ///////////////////////////////////////////////////////////////////////////////////

float sensorHorizontal = 0; // roll do Arduino
float sensorVertical   = 0; // pitch do Arduino
float botaoBruto       = 0; // valor do botao
float flexBruto        = 0; // sensor flexivel


// Valores On (so tem valor se estiver mapeado na tabela) ///////////////////////////////////////////////////////////////////////////////////

float pitchOn  = 0;
float reverbOn = 0;
float bassOn   = 0;
float flexOn   = 0;


// Som ///////////////////////////////////////////////////////////////////////////////////

SoundFile somPrincipal;   // som principal importado
SoundFile sfx1;           // efeito sonoro 1 (tecla G)
SoundFile sfx2;           // efeito sonoro 2 (tecla H)
Reverb    reverb;         // efeito de reverb ligado ao som principal

boolean aTOcar        = false; // som principal esta a tocar?
boolean somCarregado  = false; // som principal foi importado?
boolean sfx1Carregado = false;
boolean sfx2Carregado = false;


// Calibracao ///////////////////////////////////////////////////////////////////////////////////

float calibOffsetX    = 0;    // posicao X do rato no momento da calibracao
float calibOffsetY    = 0;    // posicao Y do rato no momento da calibracao

int   estadoApp       = 0;    // 0 = a calibrar, 1 = app normal
int   CALIB_TEMPO     = 3000; // tempo que tem de ficar quieto (ms)
float CALIB_LIMITE    = 4.0;  // movimento maximo permitido durante calibracao
float calibContagem   = 0;    // progresso atual da calibracao em ms
float calibUltimoX    = 0;    // posicao do rato no frame anterior
float calibUltimoY    = 0;
boolean calibAviso    = false; // mostrar aviso de calibracao
int   calibAvisoTimer = 0;    // contador para calibracao


// Cores ///////////////////////////////////////////////////////////////////////////////////

color COR_FUNDO     = color(13, 10, 46);
color COR_PAINEL    = color(25, 20, 70);
color COR_CONTORNO  = color(255, 255, 255, 60);
color COR_TEXTO     = color(255, 255, 255, 200);
color COR_DESTAQUE  = color(140, 120, 255);  // roxo — valor positivo
color COR_LARANJA   = color(255, 140, 60);   // laranja — valor negativo
color COR_VERDE     = color(100, 255, 160);
color COR_FLEX      = color(255, 180, 80);
color COR_LISTA_BG  = color(18, 14, 58);
color COR_LISTA_HOV = color(55, 45, 130);
color COR_PLAY      = color(100, 255, 160);
color COR_PAUSA     = color(255, 180, 80);
color COR_DESLIGADO = color(60, 55, 100);
color COR_HOVER     = color(50, 40, 110);    // cor dos botoes quando hover


// Fonte ///////////////////////////////////////////////////////////////////////////////////

PFont fonte;
int LARGURA, ALTURA; // dimensoes da janela


// Opcoes da tabela ///////////////////////////////////////////////////////////////////////////////////

String[] OPCOES_EFEITO    = {"Pitch", "Reverb", "Bass", "Flex"};
String[] OPCOES_MOVIMENTO = {"Hand Tilt (horizontal)", "Hand Tilt (vertical)", "Button Press", "Flex"};


// Rows da tabela ///////////////////////////////////////////////////////////////////////////////////

int MAX_ROWS = 8; // maximo de rows
int numRows  = 1; // rows atuais (comeca com 1)
int[][] rows = new int[MAX_ROWS][2]; // cada row guarda [efeito, movimento], -1 = nao escolhido


// Estado da lista ///////////////////////////////////////////////////////////////////////////////////

// listaAberta: 0 = fechada, 1 = coluna efeito, 2 = coluna movimento
int listaAberta = 0;
int listaRow    = -1; // qual row tem lista aberta
int listaHover  = -1; // item da lista com hover


// Tamanhos da tabela ///////////////////////////////////////////////////////////////////////////////////

int tabelaX, tabelaY;
int COL_EFEITO    = 160;
int COL_MOVIMENTO = 230;
int COL_VALOR     = 140;
int ALTURA_ROW    = 56;
int ESPACO_ROW    = 8;
int RAIO_PILL     = 10;
int ALTURA_ITEM   = 32;


// Posicoes dos botoes de som ///////////////////////////////////////////////////////////////////////////////////

int PLAY_X = 50;
int PLAY_Y = 0; // calculado no setup
int PLAY_W = 120;
int PLAY_H = 48;

int IMP_MAIN_X, IMP_MAIN_Y;
int IMP_SFX1_X, IMP_SFX1_Y;
int IMP_SFX2_X, IMP_SFX2_Y;
int IMP_W = 160;
int IMP_H = 40;


// Setup ///////////////////////////////////////////////////////////////////////////////////

void setup() {
  // Inicia a serial port
  myPort = new Serial(this, "COM6", 9600); // starts the serial communication
  myPort.bufferUntil('\n');

  //println(Serial.list());
  //if (Serial.list().length > 0) {
  //myPort = new Serial(this, Serial.list()[0], 9600);
  //myPort.bufferUntil('\n');
  //}

  size(1280, 800, P3D);
  smooth(8);

  LARGURA = width;
  ALTURA  = height;

  // posicao da tabela (lado direito do ecra)
  tabelaX = LARGURA / 2 + 70;
  tabelaY = ALTURA / 2 - 240;

  // posicao do botao play
  PLAY_Y = ALTURA - 80;

  // posicoes dos botoes de importar som
  IMP_MAIN_X = 50;
  IMP_MAIN_Y = ALTURA - 200;
  IMP_SFX1_X = 50;
  IMP_SFX1_Y = ALTURA - 250;
  IMP_SFX2_X = 50;
  IMP_SFX2_Y = ALTURA - 300;

  // inicia todas as rows da tabela como vazias
  for (int i = 0; i < MAX_ROWS; i++) {
    rows[i][0] = -1;
    rows[i][1] = -1;
  }

  // tenta carregar o modelo 3D
  try {
    modeloMao = loadShape("maod.obj");
    if (modeloMao != null) modeloMao.disableStyle();
  }
  catch (Exception e) {
    modeloMao = null;
  }

  // inicia o reverb (sem efeito no inicio)
  reverb = new Reverb(this);

  fonte = createFont("Helvetica Neue", 14, true);
  textFont(fonte);

  // guarda posicao inicial do rato para calibracao
  calibUltimoX = mouseX;
  calibUltimoY = mouseY;
}


// Draw ///////////////////////////////////////////////////////////////////////////////////

void draw() {
  background(COR_FUNDO);

  if (estadoApp == 0) {
    // modo calibracao
    desenharCalibracao();
  } else {
    // modo normal
    atualizarSensores();
    aplicarMapeamentos();
    aplicarEfeitos();
    desenharNavbar();
    desenharMao3D();
    desenharArduinoInputs();
    desenharBarraEstado();
    desenharPainelSom();
    desenharTabela();
    desenharBotaoAdicionar();
    if (listaAberta != 0) desenharLista();
  }
}


// Calibracao ///////////////////////////////////////////////////////////////////////////////////

void desenharCalibracao() {

  // calcula quanto o rato se moveu desde o ultimo frame
  float movX      = abs(mouseX - calibUltimoX);
  float movY      = abs(mouseY - calibUltimoY);
  float movimento = movX + movY;

  if (movimento > CALIB_LIMITE) {
    // movimento detetado -> reinicia e mostra aviso
    calibContagem   = 0;
    calibAviso      = true;
    calibAvisoTimer = 90; // frames que o aviso fica visivel
  } else {
    // quieto -> avanca a contagem
    calibContagem += (1000.0 / frameRate);
  }

  // conta down do aviso
  if (calibAvisoTimer > 0) calibAvisoTimer--;
  else calibAviso = false;

  // guarda posicao atual para comparar no proximo frame
  calibUltimoX = mouseX;
  calibUltimoY = mouseY;

  // calibracao completa?
  if (calibContagem >= CALIB_TEMPO) {
    terminarCalibracao();
    return;
  }

  // titulo
  fill(255);
  textSize(28);
  textAlign(CENTER, CENTER);
  text("Calibrating", LARGURA / 2, ALTURA / 2 - 100);

  // mensagem ou aviso
  if (calibAviso) {
    fill(255, 100, 100);
    textSize(16);
    text("Do not move your hand!", LARGURA / 2, ALTURA / 2 - 60);
  } else {
    fill(COR_TEXTO);
    textSize(16);
    text("Hold your hand still in the neutral position", LARGURA / 2, ALTURA / 2 - 60);
  }

  // barra de progresso
  int barraLargura = 400;
  int barraAltura  = 12;
  int barraX = LARGURA / 2 - barraLargura / 2;
  int barraY = ALTURA / 2;

  noStroke();
  fill(COR_PAINEL);
  rect(barraX, barraY, barraLargura, barraAltura, barraAltura/2);

  float enchimento = map(calibContagem, 0, CALIB_TEMPO, 0, barraLargura);
  if (calibAviso) {
    fill(255, 100, 100);
  } else {
    fill(COR_DESTAQUE);
  }
  if (enchimento > 0) rect(barraX, barraY, enchimento, barraAltura, barraAltura/2);

  // percentagem
  fill(COR_TEXTO);
  textSize(13);
  text(int(map(calibContagem, 0, CALIB_TEMPO, 0, 100)) + "%", LARGURA / 2, barraY + 30);

  // dica
  fill(255, 255, 255, 80);
  textSize(11);
  text("Press SPACE to calibrate immediately", LARGURA / 2, ALTURA / 2 + 70);
}

void terminarCalibracao() {
  // guarda posicao atual como ponto zero
  calibOffsetX = mouseX;
  calibOffsetY = mouseY;
  estadoApp = 1; // passa para modo normal
}


// Sensores ///////////////////////////////////////////////////////////////////////////////////

void atualizarSensores() {

  sensorHorizontal = constrain(roll, -100, 100);
  sensorVertical   = constrain(pitch, -100, 100);
  botaoBruto       = constrain(button, -100, 100);
  flexBruto        = constrain(flex, -100, 100);

  // converte os valores do Arduino em angulos de rotacao
  float rotHorAlvo = map(sensorHorizontal, -100, 100, -PI * 0.6, PI * 0.6);
  float rotVerAlvo = map(sensorVertical, -100, 100, -PI * 0.3, PI * 0.3);

  // suaviza todos os valores para movimento fluido
  rotHorSuave = lerp(rotHorSuave, rotHorAlvo, 0.08);
  rotVerSuave = lerp(rotVerSuave, rotVerAlvo, 0.08);
}


// Mapeamentos da tabela ///////////////////////////////////////////////////////////////////////////////////

void aplicarMapeamentos() {

  // reseta tudo — sem rows ativas = sem efeito
  pitchOn  = 0;
  reverbOn = 0;
  bassOn   = 0;
  flexOn   = 0;

  // percorre cada row da tabela
  for (int i = 0; i < numRows; i++) {
    int idxEfeito    = rows[i][0]; // efeito escolhido
    int idxMovimento = rows[i][1]; // movimento escolhido

    // se a row estiver incompleta, ignora
    if (idxEfeito == -1 || idxMovimento == -1) continue;

    // vai buscar o valor bruto do sensor escolhido
    float valorMovimento = buscarValorMovimento(idxMovimento);

    // mapeia o movimento para o efeito escolhido
    if (idxEfeito == 0) pitchOn  = valorMovimento;
    if (idxEfeito == 1) reverbOn = valorMovimento;
    if (idxEfeito == 2) bassOn   = valorMovimento;
    if (idxEfeito == 3) flexOn   = valorMovimento;
  }
}

// devolve o valor bruto do sensor para um dado movimento
float buscarValorMovimento(int idxMovimento) {
  if (idxMovimento == 0) return sensorHorizontal;
  if (idxMovimento == 1) return sensorVertical;
  if (idxMovimento == 2) return botaoBruto;
  if (idxMovimento == 3) return flexBruto;
  return 0;
}


// Efeitos de som ///////////////////////////////////////////////////////////////////////////////////

void aplicarEfeitos() {
  if (!somCarregado) return;

  // pitch -> muda a velocidade de reproducao (0.25x = grave, 2.0x = agudo)
  float velocidade = map(pitchOn, -100, 100, 0.25, 2.0);
  somPrincipal.rate(velocidade);

  // bass -> controla o volume
  float volume = map(bassOn, 0, 100, 0.3, 1.0);
  if (bassOn < 1) volume = 0.7; // volume neutro se bass nao estiver mapeado
  somPrincipal.amp(volume);

  // reverb -> efeito de espaco/eco
  float quantidadeReverb = map(reverbOn, -100, 100, 0.0, 1.0);
  reverb.room(quantidadeReverb);
  reverb.wet(quantidadeReverb * 0.8);
}


// Navbar ///////////////////////////////////////////////////////////////////////////////////

void desenharNavbar() {
  textSize(22);
  fill(255, 255, 255, 180);
  textAlign(LEFT, CENTER);
  text("hand", 50, 42);
  fill(255);
  text("TheSound", 50 + textWidth("hand"), 42);
  fill(COR_TEXTO);
  textSize(16);
  textAlign(RIGHT, CENTER);
  text("info", LARGURA - 200, 42);
  text("contact us", LARGURA - 50, 42);
}


// Mao 3D ///////////////////////////////////////////////////////////////////////////////////

void desenharMao3D() {
  pushMatrix();
  translate(LARGURA * 0.27, ALTURA * 0.50 + 40, 0);
  rotateX(PI);
  rotateX(rotVerSuave);
  rotateY(rotHorSuave);
  lights();
  directionalLight(220, 210, 255, -0.4, 0.5, -1);
  ambientLight(60, 50, 90);
  fill(240, 235, 250);
  noStroke();
  scale(18.0, 18.0, 18.0);
  shape(modeloMao, 0, 0);
  popMatrix();
  noLights();
}


// Arduino inputs ///////////////////////////////////////////////////////////////////////////////////

void desenharArduinoInputs() {
  int bx = LARGURA - 170;
  int by = ALTURA - 165;
  int bw = 18;
  int bh = 100;
  desenharUmaFlexBar(bx, by, bw, bh, sensorHorizontal, "Roll");
  desenharUmaFlexBar(bx + 36, by, bw, bh, sensorVertical, "Pitch");
  desenharUmaFlexBar(bx + 72, by, bw, bh, botaoBruto, "Button");
  desenharUmaFlexBar(bx + 108, by, bw, bh, flexBruto, "Flex");
}

void desenharUmaFlexBar(int x, int y, int bw, int bh, float val, String nome) {

  // fundo da barra
  noStroke();
  fill(COR_PAINEL);
  rect(x, y, bw, bh, bh/2);

  // enchimento da barra
  float normalized = map(constrain(val, -100, 100), -100, 100, 0, 1);
  float enchimento = bh * normalized;
  if (val >= 0) {
    fill(lerpColor(color(80, 70, 140), COR_FLEX, normalized));
  } else {
    fill(lerpColor(color(80, 70, 140), COR_LARANJA, normalized));
  }
  if (enchimento > 0) rect(x, y + bh - enchimento, bw, enchimento, enchimento/2);

  // nome em baixo
  fill(COR_TEXTO);
  textSize(10);
  textAlign(CENTER, TOP);
  text(nome, x + bw / 2, y + bh + 6);

  fill(255, 255, 255, 90);
  textSize(9);
  textAlign(CENTER, BOTTOM);
  text(nf(val, 0, 0), x + bw / 2, y - 6);
}


// Barra de estado ///////////////////////////////////////////////////////////////////////////////////

void desenharBarraEstado() {
  // ponto verde a indicar que esta ligado ao Arduino
  noStroke();
  fill(COR_VERDE);
  ellipse(LARGURA - 290, ALTURA - 30, 8, 8);

  fill(255, 255, 255, 160);
  textSize(13);
  textAlign(RIGHT, BOTTOM);
    text("Arduino is connected", LARGURA - 50, ALTURA - 22);

  fill(255, 255, 255, 55);
  textSize(10);
  textAlign(CENTER, CENTER);
  text("roll -> horizontal  |  pitch -> vertical  |  button -> press  |  flex -> flex sensor", LARGURA/2, 42);
}


// Painel de som ///////////////////////////////////////////////////////////////////////////////////

void desenharPainelSom() {

  // verifica se o rato esta por cima de cada botao (hover)
  boolean hoverMain = ratoEmCima(IMP_MAIN_X, IMP_MAIN_Y, IMP_W, IMP_H);
  boolean hoverSfx1 = ratoEmCima(IMP_SFX1_X, IMP_SFX1_Y, IMP_W, IMP_H);
  boolean hoverSfx2 = ratoEmCima(IMP_SFX2_X, IMP_SFX2_Y, IMP_W, IMP_H);
  boolean hoverPlay = ratoEmCima(PLAY_X, PLAY_Y, PLAY_W, PLAY_H);

  // botao importar som principal
  desenharBotaoImportar(IMP_MAIN_X, IMP_MAIN_Y, IMP_W, IMP_H,
    somCarregado ? "Main: carregado \u2713" : "Importar Som Principal",
    somCarregado, hoverMain);

  // botao importar SFX 1
  desenharBotaoImportar(IMP_SFX1_X, IMP_SFX1_Y, IMP_W, IMP_H,
    sfx1Carregado ? "SFX 1: carregado \u2713" : "Importar SFX 1  [G]",
    sfx1Carregado, hoverSfx1);

  // botao importar SFX 2
  desenharBotaoImportar(IMP_SFX2_X, IMP_SFX2_Y, IMP_W, IMP_H,
    sfx2Carregado ? "SFX 2: carregado \u2713" : "Importar SFX 2  [H]",
    sfx2Carregado, hoverSfx2);

  // cor do botao play: desligado / a tocar / parado / hover
  color corBotaoPlay;
  if (!somCarregado) {
    corBotaoPlay = COR_DESLIGADO;
  } else if (aTOcar) {
    corBotaoPlay = COR_PAUSA;
  } else if (hoverPlay) {
    corBotaoPlay = COR_HOVER;
  } else {
    corBotaoPlay = COR_PLAY;
  }

  noStroke();
  fill(corBotaoPlay);
  rect(PLAY_X, PLAY_Y, PLAY_W, PLAY_H, PLAY_H/2);

  // texto do botao play
  if (somCarregado) {
    fill(color(13, 10, 46));
  } else {
    fill(255, 255, 255, 60);
  }
  textSize(14);
  textAlign(CENTER, CENTER);

  String labelPlay;
  if (!somCarregado) {
    labelPlay = "Sem Som";
  } else if (aTOcar) {
    labelPlay = "\u23F8  Pausa";
  } else {
    labelPlay = "\u25B6  Play";
  }
  text(labelPlay, PLAY_X + PLAY_W / 2, PLAY_Y + PLAY_H / 2);

  // indicador "pronto" ao lado do botao play
  if (somCarregado) {
    fill(COR_VERDE);
    textSize(10);
    textAlign(LEFT, CENTER);
    text("pronto", PLAY_X + PLAY_W + 12, PLAY_Y + PLAY_H / 2);
  }
}

// desenha um botao de importar com hover
void desenharBotaoImportar(int x, int y, int w, int h, String label, boolean carregado, boolean hover) {

  noStroke();

  // fundo: verde escuro se carregado, hover se por cima, painel normal
  if (carregado) {
    fill(color(40, 80, 60));
  } else if (hover) {
    fill(COR_HOVER);
  } else {
    fill(COR_PAINEL);
  }
  rect(x, y, w, h);

  // contorno
  if (carregado) {
    stroke(COR_VERDE);
  } else if (hover) {
    stroke(COR_DESTAQUE);
  } else {
    stroke(COR_CONTORNO);
  }
  strokeWeight(1);
  noFill();
  rect(x, y, w, h);

  // texto
  noStroke();
  if (carregado) {
    fill(COR_VERDE);
  } else {
    fill(COR_TEXTO);
  }
  textSize(11);
  textAlign(CENTER, CENTER);
  text(label, x + w / 2, y + h / 2);
}

// verifica se o rato esta dentro de uma area rectangular
boolean ratoEmCima(int x, int y, int w, int h) {
  return (mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h);
}


// Abrir ficheiro de som ///////////////////////////////////////////////////////////////////////////////////

String abrirFicheiro() {
  // abre dialogo do sistema para escolher ficheiro de audio
  JFileChooser seletor = new JFileChooser();
  FileNameExtensionFilter filtro = new FileNameExtensionFilter(
    "Ficheiros de audio (wav, mp3, aiff)", "wav", "mp3", "aiff");
  seletor.setFileFilter(filtro);
  int resultado = seletor.showOpenDialog(null);
  if (resultado == JFileChooser.APPROVE_OPTION) {
    return seletor.getSelectedFile().getAbsolutePath();
  }
  return null; // utilizador cancelou
}

void carregarSomPrincipal(String caminho) {
  if (somPrincipal != null) somPrincipal.stop();
  somPrincipal = new SoundFile(this, caminho);
  reverb.process(somPrincipal); // liga o reverb ao som
  somCarregado = true;
  aTOcar = false;
}

void carregarSFX1(String caminho) {
  if (sfx1 != null) sfx1.stop();
  sfx1 = new SoundFile(this, caminho);
  sfx1Carregado = true;
}

void carregarSFX2(String caminho) {
  if (sfx2 != null) sfx2.stop();
  sfx2 = new SoundFile(this, caminho);
  sfx2Carregado = true;
}


// Tabela ///////////////////////////////////////////////////////////////////////////////////

void desenharTabela() {
  int tx = tabelaX;
  int ty = tabelaY;
  int larguraTotal = COL_EFEITO + COL_MOVIMENTO + COL_VALOR;

  // cabecalhos
  fill(COR_TEXTO);
  textSize(12);
  textAlign(CENTER, CENTER);
  text("Effect", tx + COL_EFEITO / 2, ty - 22);
  text("Movement", tx + COL_EFEITO + COL_MOVIMENTO / 2, ty - 22);
  text("Value", tx + COL_EFEITO + COL_MOVIMENTO + COL_VALOR / 2, ty - 22);

  // linha separadora
  stroke(COR_CONTORNO);
  strokeWeight(1);
  line(tx, ty - 8, tx + larguraTotal, ty - 8);
  noStroke();

  // desenha cada row
  for (int i = 0; i < numRows; i++) {
    desenharRow(i, tx, ty + i * (ALTURA_ROW + ESPACO_ROW));
  }
}

void desenharBotaoAdicionar() {
  // botao + para adicionar nova row
  int botaoY = tabelaY + numRows * (ALTURA_ROW + ESPACO_ROW) + 8;
  boolean podeAdicionar = numRows < MAX_ROWS;
  float alfa = podeAdicionar ? 200 : 60;

  stroke(red(COR_CONTORNO), green(COR_CONTORNO), blue(COR_CONTORNO), alfa);
  strokeWeight(1);
  noFill();
  rect(tabelaX, botaoY, 130, 44, 22);
  noStroke();
  fill(255, 255, 255, alfa);
  textSize(20);
  textAlign(CENTER, CENTER);
  text("+", tabelaX + 65, botaoY + 22);
}

void desenharRow(int idxRow, int x, int y) {
  int idxEfeito    = rows[idxRow][0];
  int idxMovimento = rows[idxRow][1];
  int espaco = 6;

  // pill do efeito — cor fixa, so muda quando lista esta aberta nesta row
  boolean listaEfeitoAberta = (listaAberta == 1 && listaRow == idxRow);
  noStroke();
  if (listaEfeitoAberta) {
    fill(color(55, 45, 130));
  } else {
    fill(COR_PAINEL);
  }
  rect(x, y, COL_EFEITO - espaco, ALTURA_ROW, RAIO_PILL);
  textAlign(CENTER, CENTER);
  textSize(13);
  if (idxEfeito == -1) {
    fill(255, 255, 255, 80);
    text("Choose effect \u25be", x + (COL_EFEITO - espaco) / 2, y + ALTURA_ROW / 2);
  } else {
    fill(255);
    text(OPCOES_EFEITO[idxEfeito], x + (COL_EFEITO - espaco) / 2, y + ALTURA_ROW / 2);
  }

  // pill do movimento — cor fixa, so muda quando lista esta aberta nesta row
  boolean listaMovAberta = (listaAberta == 2 && listaRow == idxRow);
  if (listaMovAberta) {
    fill(color(55, 45, 130));
  } else {
    fill(COR_PAINEL);
  }
  rect(x + COL_EFEITO, y, COL_MOVIMENTO - espaco, ALTURA_ROW, RAIO_PILL);
  if (idxMovimento == -1) {
    fill(255, 255, 255, 80);
    text("Choose movement \u25be", x + COL_EFEITO + (COL_MOVIMENTO - espaco) / 2, y + ALTURA_ROW / 2);
  } else {
    fill(255);
    text(OPCOES_MOVIMENTO[idxMovimento], x + COL_EFEITO + (COL_MOVIMENTO - espaco) / 2, y + ALTURA_ROW / 2);
  }

  // pill do valor — muda de cor consoante o valor do sensor
  // positivo (+100) -> roxo | neutro (0) -> cor do painel | negativo (-100) -> laranja
  boolean rowAtiva = (idxEfeito != -1 && idxMovimento != -1);
  float valor = 0;
  if (rowAtiva) {
    valor = buscarValorMovimento(idxMovimento);
  }

  color corValor = COR_PAINEL; // cor base quando row nao esta ativa

  if (rowAtiva) {
    if (valor >= 0) {
      // positivo: interpolacao entre painel e roxo
      float intensidade = map(valor, 0, 100, 0, 0.6);
      corValor = lerpColor(COR_PAINEL, COR_DESTAQUE, intensidade);
    } else {
      // negativo: interpolacao entre painel e laranja
      float intensidade = map(valor, 0, -100, 0, 0.6);
      corValor = lerpColor(COR_PAINEL, COR_LARANJA, intensidade);
    }
  }

  fill(corValor);
  rect(x + COL_EFEITO + COL_MOVIMENTO, y, COL_VALOR - espaco, ALTURA_ROW, RAIO_PILL);

  if (rowAtiva) {
    fill(255);
    textSize(15);
    boolean eFlex = (idxEfeito == 3 || idxEfeito == 4);
    String textoValor = "";
    if (eFlex) {
      textoValor = nf(valor, 0, 0) + "%";
    } else {
      if (valor >= 0) {
        textoValor = "+" + nf(valor, 0, 1);
      } else {
        textoValor = nf(valor, 0, 1);
      }
    }
    text(textoValor, x + COL_EFEITO + COL_MOVIMENTO + (COL_VALOR - espaco) / 2, y + ALTURA_ROW / 2);
  } else {
    fill(255, 255, 255, 35);
    textSize(13);
    text("\u2014", x + COL_EFEITO + COL_MOVIMENTO + (COL_VALOR - espaco) / 2, y + ALTURA_ROW / 2);
  }
}


// Lista (dropdown) ///////////////////////////////////////////////////////////////////////////////////

void desenharLista() {
  String[] opcoes;
  if (listaAberta == 1) {
    opcoes = OPCOES_EFEITO;
  } else {
    opcoes = OPCOES_MOVIMENTO;
  }

  int rowY   = tabelaY + listaRow * (ALTURA_ROW + ESPACO_ROW);
  int listaX, listaW;
  if (listaAberta == 1) {
    listaX = tabelaX;
    listaW = COL_EFEITO - 6;
  } else {
    listaX = tabelaX + COL_EFEITO;
    listaW = COL_MOVIMENTO - 6;
  }
  int listaY = rowY + ALTURA_ROW + 4;
  int listaH = opcoes.length * ALTURA_ITEM + 8;

  // sombra
  noStroke();
  fill(10, 8, 35, 200);
  rect(listaX + 3, listaY + 3, listaW, listaH);

  // fundo da lista
  fill(COR_LISTA_BG);
  rect(listaX, listaY, listaW, listaH);

  // itens da lista
  for (int i = 0; i < opcoes.length; i++) {
    int itemY    = listaY + 4 + i * ALTURA_ITEM;
    boolean comHover = (i == listaHover);
    if (comHover) {
      fill(COR_LISTA_HOV);
      rect(listaX + 4, itemY, listaW - 8, ALTURA_ITEM);
    }
    if (comHover) {
      fill(255);
    } else {
      fill(COR_TEXTO);
    }
    textSize(12);
    textAlign(LEFT, CENTER);
    text(opcoes[i], listaX + 16, itemY + ALTURA_ITEM / 2);
  }
}


// Eventos de rato ///////////////////////////////////////////////////////////////////////////////////

void mousePressed() {

  // durante calibracao nao faz nada
  if (estadoApp == 0) return;

  // se lista aberta, verifica se clicou num item
  if (listaAberta != 0) {
    String[] opcoes;
    if (listaAberta == 1) {
      opcoes = OPCOES_EFEITO;
    } else {
      opcoes = OPCOES_MOVIMENTO;
    }

    int rowY   = tabelaY + listaRow * (ALTURA_ROW + ESPACO_ROW);
    int listaX, listaW;
    if (listaAberta == 1) {
      listaX = tabelaX;
      listaW = COL_EFEITO - 6;
    } else {
      listaX = tabelaX + COL_EFEITO;
      listaW = COL_MOVIMENTO - 6;
    }
    int listaY = rowY + ALTURA_ROW + 4;
    int listaH = opcoes.length * ALTURA_ITEM + 8;

    if (mouseX >= listaX && mouseX <= listaX + listaW &&
      mouseY >= listaY && mouseY <= listaY + listaH) {
      int itemClicado = (mouseY - listaY - 4) / ALTURA_ITEM;
      if (itemClicado >= 0 && itemClicado < opcoes.length) {
        rows[listaRow][listaAberta - 1] = itemClicado; // guarda escolha
      }
    }
    // fecha lista
    listaAberta = 0;
    listaRow    = -1;
    listaHover  = -1;
    return;
  }

  // clique no botao play
  if (ratoEmCima(PLAY_X, PLAY_Y, PLAY_W, PLAY_H)) {
    if (somCarregado) {
      if (aTOcar) {
        somPrincipal.stop(); // para e volta ao inicio
        aTOcar = false;
      } else {
        somPrincipal.play(); // toca do inicio
        aTOcar = true;
      }
    }
    return;
  }

  // clique no botao importar som principal
  if (ratoEmCima(IMP_MAIN_X, IMP_MAIN_Y, IMP_W, IMP_H)) {
    String caminho = abrirFicheiro();
    if (caminho != null) carregarSomPrincipal(caminho);
    return;
  }

  // clique no botao importar SFX 1
  if (ratoEmCima(IMP_SFX1_X, IMP_SFX1_Y, IMP_W, IMP_H)) {
    String caminho = abrirFicheiro();
    if (caminho != null) carregarSFX1(caminho);
    return;
  }

  // clique no botao importar SFX 2
  if (ratoEmCima(IMP_SFX2_X, IMP_SFX2_Y, IMP_W, IMP_H)) {
    String caminho = abrirFicheiro();
    if (caminho != null) carregarSFX2(caminho);
    return;
  }

  // cliques nas pills da tabela
  for (int i = 0; i < numRows; i++) {
    int rx = tabelaX;
    int ry = tabelaY + i * (ALTURA_ROW + ESPACO_ROW);

    // clique na pill do efeito
    if (mouseX >= rx && mouseX <= rx + COL_EFEITO - 6 &&
      mouseY >= ry && mouseY <= ry + ALTURA_ROW) {
      listaAberta = 1;
      listaRow    = i;
      listaHover  = -1;
      return;
    }

    // clique na pill do movimento
    int movX = rx + COL_EFEITO;
    if (mouseX >= movX && mouseX <= movX + COL_MOVIMENTO - 6 &&
      mouseY >= ry   && mouseY <= ry + ALTURA_ROW) {
      listaAberta = 2;
      listaRow    = i;
      listaHover  = -1;
      return;
    }
  }

  // clique no botao +
  int botaoY = tabelaY + numRows * (ALTURA_ROW + ESPACO_ROW) + 8;
  if (mouseX >= tabelaX && mouseX <= tabelaX + 130 &&
    mouseY >= botaoY  && mouseY <= botaoY + 44   &&
    numRows < MAX_ROWS) {
    numRows++;
  }
}

void mouseMoved() {
  atualizarHoverLista();
}
void mouseDragged() {
  atualizarHoverLista();
}

void atualizarHoverLista() {
  if (listaAberta == 0) return;

  int rowY   = tabelaY + listaRow * (ALTURA_ROW + ESPACO_ROW);
  int listaX, listaW;
  if (listaAberta == 1) {
    listaX = tabelaX;
    listaW = COL_EFEITO - 6;
  } else {
    listaX = tabelaX + COL_EFEITO;
    listaW = COL_MOVIMENTO - 6;
  }
  int listaY = rowY + ALTURA_ROW + 4;

  String[] opcoes;
  if (listaAberta == 1) {
    opcoes = OPCOES_EFEITO;
  } else {
    opcoes = OPCOES_MOVIMENTO;
  }

  listaHover = -1;
  if (mouseX >= listaX && mouseX <= listaX + listaW) {
    int item = (mouseY - listaY - 4) / ALTURA_ITEM;
    if (item >= 0 && item < opcoes.length) listaHover = item;
  }
}


// Teclado ///////////////////////////////////////////////////////////////////////////////////

void keyPressed() {

  // espaco confirma calibracao ja
  if (estadoApp == 0 && key == ' ') {
    terminarCalibracao();
    return;
  }

  // reset posicao da mao
  if (key == 'r' || key == 'R') {
    rotHorSuave = 0;
    rotVerSuave = 0;
  }

  // sfx 1 - toca uma vez por pressao
  if ((key == 'g' || key == 'G') && sfx1Carregado) {
    sfx1.stop();
    sfx1.play();
  }

  // sfx 2 - toca uma vez por pressao
  if ((key == 'h' || key == 'H') && sfx2Carregado) {
    sfx2.stop();
    sfx2.play();
  }

  // ESC fecha lista em vez de fechar o programa
  if (keyCode == ESC) {
    listaAberta = 0;
    listaRow    = -1;
    key = 0;
  }
}

void keyReleased() {
}


// Read arduino data ///////////////////////////////////////////////////////////////////////////////////
void serialEvent (Serial myPort) {
  data = myPort.readStringUntil('\n');

  if (data != null) {
    data = trim(data);
    String items[] = split(data, '/');
    if (items.length == 4) {
      try {
        roll = float(items[0]);
        pitch = float(items[1]);
        button = float(items[2]);
        flex = float(items[3]);
      }
      catch (Exception ignored) {
      }
    }
  }
}