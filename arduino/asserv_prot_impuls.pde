/** Timers pour interruptions régulières **/
#include <SimpleTimer.h>
SimpleTimer timerAsservPWM;
SimpleTimer timerPasAPas;

/** constantes pour les codeuses **/
const byte pinSignal1 = 2;// pin d'interruption 0 pour le premier signal
const byte pinSignal2 = 3;// pin d'interruption 1 pour le second signal

/** constantes pour le moteur à courant continu **/
const byte pinDIR = 4;                   // pin de direction du moteur à courant continu
const byte pinPWM = 5;                   // pin de PWM du moteur à courant continu
const int frequence_asserv = 150;        // fréquence de mise à jour du PWM, en Hz
const float nb_ticks_1mm = 4.837070254;  //constante de conversion

/** constantes pour le moteur pas à pas **/
const byte pinSENS  = 6;    // pin de sens du moteur pas à pas
const byte pinCLOCK = 7;    // pin d'impulsion du moteur pas à pas
const byte pinENABLE = 8;   // pin d'activation du moteur pas à pas
//const int frequence_PasAPas = 630;  // fréquence d'envoi des impulsions au pas à pas, en Hz
const int frequence_PasAPas = 700;  // fréquence d'envoi des impulsions au pas à pas, en Hz

/** variables globales, partagées par plusieurs fonctions **/
long ticks = 0;          // ticks mesurés par l'encodeur et pris en compte par l'asservissement 
long consigne_ticks = 0; // consigne reçue de position du moteur à courant continu, en ticks
//constantes d'asservissement pid
float kp = 50.0;         // Coefficient proportionnel
float ki = 0.0;         // Coefficient intégrateur
float kd = 0.0;         // Coefficient dérivateur
byte bridage_pwm = 150;   // Valeur de bridage du PWM
int pas = 0;            // position du moteur pas à pas depuis le dernier recalage, valeur en pas
int consigne_pas = 0;   // consigne reçue de position du moteur pas à pas, en pas

//***  niveaux de prescaler  ***//
//int mode = 0b00000001; float prescaler = 64.;// 62kHz
int mode = 0b00000010; float prescaler = 8.;// 7.8kHz
  
/** Routine d'initialisation **/
void setup() {
    //overclock du timer (nécessaire pour le pas à pas)
    TCCR0B = TCCR0B & 0b11111000 | mode;
  
    //serie
    Serial.begin(9600);
    
    //interruptions externes (réception des ticks de la codeuse)
    attachInterrupt(0, update_ticks, CHANGE); // sur arduino duemilanove, pin2 = pin d'interruption 0
    attachInterrupt(1, update_ticks, CHANGE); //                       et pin3 = pin d'interruption 1
    
    //initialisation des broches de
    pinMode(pinPWM,  OUTPUT);
    pinMode(pinDIR,  OUTPUT);
    pinMode(pinSENS, OUTPUT);
    pinMode(pinCLOCK,OUTPUT);
    pinMode(pinENABLE,OUTPUT);
    
    //immobilisation initiale du moteur
    analogWrite(pinPWM, 0);
    
    // Interruptions pour calcul du PID et asservissement
    timerAsservPWM.setInterval(1000./(frequence_asserv/prescaler), asservissementPWM);
    // pour les impulsions du pas à pas (la fréquence est doublée pour générer les fronts)
    timerPasAPas.setInterval(1000./(2*frequence_PasAPas/prescaler), gestionPasAPas);
    
    Serial.print("init\n");
}

/** lecture (blocante) d'une ligne sur la série **/
String readLine()
{
  String inString = "";
  while (Serial.available() == 0)
  {
    // On continue à évaluer les interruptions timer
    timerAsservPWM.run();
    timerPasAPas.run();
  }
  char inChar = Serial.read();
  while (inChar != '\n' and inChar != '\r') // attente d'une fin de ligne
  {
    // On continue à évaluer les interruptions timer
    timerAsservPWM.run();
    timerPasAPas.run();
    if (Serial.available() > 0) {
      inString += (char)inChar; 
      inChar = Serial.read();
    }
  }
  return inString;
}

/** Boucle principale (protocole série) **/
void loop(){
  String msg = readLine();
  
  //ping
  if (msg == "?") {
    Serial.println("#");
  }
  
  //modification des constantes d'asservissement
  //en millième ! Il faut entrer 1300 pour spécifier 1.300
  else if (msg == "kp") {
    kp = readLine().toInt()/1000.;
  }
  else if (msg == "ki") {
    ki = readLine().toInt()/1000.;
  }
  else if (msg == "kd") {
    kd = readLine().toInt()/1000.;
  }
  //valeur max du PWM (valeur absolue)
  else if (msg == "vm") {
    bridage_pwm = readLine().toInt();
  }
  
  //affichage des constantes d'asservissement
  else if (msg == "?pid") {
    Serial.print("kp : ");
    Serial.print(kp);
    Serial.print(", ki : ");
    Serial.print(ki);
    Serial.print(", kd : ");
    Serial.print(kd);
    Serial.print("\n");
  }
  
  //consigne au moteur à courant continu
  else if (msg == "cm") {
    consigne_ticks = readLine().toInt() * nb_ticks_1mm;
  }
  
  //consigne au moteur pas à pas
  else if (msg == "cp") {
    consigne_pas = readLine().toInt();
  }
  
  //reset des pas
  else if (msg == "rp") {
    consigne_pas = 0;
    pas = 0;
  }
  
  //debug des ticks
  else if (msg == "ticks") {
    Serial.print("ticks : ");
    Serial.print(ticks);
    Serial.print(", consigne : ");
    Serial.print(consigne_ticks);
    Serial.print("\n");
  }
  
  //debug du PWM
  else if (msg == "pwm") {
    consigne_ticks = readLine().toInt();
  }
}

void update_ticks()
{
  //sauvegarde des états précédents des 2 signaux de la codeuse
  static int lastS1 = 0;
  static int lastS2 = 0;
  
  //sauvegarde du sens de parcourt de la roue codeuse
  static int sens = 0;
  
  //récupération de l'état des signaux de la codeuse
  int currentS1 = digitalRead(pinSignal1);
  int currentS2 = digitalRead(pinSignal2);
  
  //détermination du sens de rotation de la roue codeuse grace aux états des 2 signaux
  if (currentS1 != lastS1 or currentS2 != lastS2)
  {
    //incrémentation des ticks en fonction du sens de parcours
    if(lastS1 xor currentS2)
      sens = 1;
    else
      sens = -1;
  }
  
  //états précédents
  lastS1 = currentS1;
  lastS2 = currentS2;
  
  ticks += sens;
}
 
/** Calcul du nouveau PWM avec asservissement PID **/
void asservissementPWM()
{
    static long somme_erreur = 0;// pour l'intégrateur
    static long erreur_precedente = 0;  // pour le dérivateur
    
    // Calcul des erreurs
    long erreur = consigne_ticks - ticks;
    somme_erreur += erreur;
    long delta_erreur = erreur-erreur_precedente;
    erreur_precedente = erreur;

    // PID : calcul de la commande
    long pwm = kp*erreur + ki*somme_erreur + kd*delta_erreur;
 
    // Normalisation du PWM
    if(pwm < -bridage_pwm)
        pwm = -bridage_pwm;
    else if(pwm > bridage_pwm)
        pwm = bridage_pwm;
        
        
    if(abs(pwm) < kp+5)
      //évite de forcer inutilement
      analogWrite(pinPWM, 0);
      
    else
    {
      //Contrôle du moteur
      if(pwm < 0)
      {
          digitalWrite(pinDIR, HIGH);
          analogWrite(pinPWM, -pwm);
      }
      else
      {
          digitalWrite(pinDIR, LOW);
          analogWrite(pinPWM, pwm);
      }
    }
}

/** Gestion de la broche Clock du moteur pas à pas **/
void gestionPasAPas()
{
  static boolean frontMontant = false;
  if (frontMontant)
    _frontMontantPAP();
  else
    _frontDescendantPAP();
  frontMontant = !frontMontant;
}

/** Envoit ou non une impulsion au moteur pas à pas **/
void _frontMontantPAP()
{
  int erreur = consigne_pas - pas;
  if (erreur < 0)
  {
      digitalWrite(pinENABLE, HIGH); //activation du moteur
      digitalWrite(pinSENS, LOW);
      digitalWrite(pinCLOCK, HIGH);
      pas--;
  }
  else if (erreur > 0)
  {
      digitalWrite(pinENABLE, HIGH); //activation du moteur
      digitalWrite(pinSENS, HIGH);
      digitalWrite(pinCLOCK, HIGH);
      pas++;
  }
  else
  {
      digitalWrite(pinENABLE, LOW); //desactivation du moteur (évite de vibrer)
  }
}

/** Remise à zéro du niveau logique (pour générer le créneau) **/
void _frontDescendantPAP()
{
  digitalWrite(pinCLOCK, LOW);
}
