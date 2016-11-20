/*
 * start muse driver MUSEIO
 * muse-io --preset 14 --50hz --dsp --osc osc.udp://localhost:5001,osc.udp://localhost:5002
 */

/* OSC communication imports */
import processing.serial.*;
import oscP5.*;
import netP5.*;
/* Hue Http imports */
import org.apache.http.HttpEntity;
import org.apache.http.HttpResponse;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.impl.client.DefaultHttpClient;

OscP5 oscP5;
NetAddressList myNetAddressList = new NetAddressList();
int myListeningPort = 5001;
int myBroadcastPort = 12000;

// hue address
String hueAddress = "192.168.1.11";

boolean doMuse = true;
boolean ready = false;

String myConnectPattern = "/eeg/connect";
String myDisconnectPattern = "/eeg/disconnect";

PFont myFont;

/* muse values */
int eeg_output_frequency_hz = 0;     // output frequency in hz
int notch_frequency_hz = 0;          // notch frequency in hz 
int battery_percent_remaining = 0;   // remaining battery
int status_indicator[];              // satus indicator (1=good, 2=ok, >3=bad)
int dropped_samples = 0;             // number of dropped samples 
float museEEG[];                     // wave value
String[] museEEGband = {             // waves
  "Delta (1-4)", "Theta (5-8)", "Alpha (9-13)", "Beta (13-30)", "Gamma (30-50)" 
  };
  
/* hue objects */
HueHub hub;
HueLight light_1;
HueLight light_2;
HueLight light_3;

void setup() {
  size(400,300);  // window size
  
  /* Muse */
  // listen at port 5001
  oscP5 = new OscP5(this, myListeningPort);
  
  // unique font display
  // myFont = createFont("", 16);
  // textFont(myFont);
  // textLeading(25);
  
  // set status indicators and wave values to zero
  status_indicator = new int[4];
  for (int i=0; i<4; i++) status_indicator[i] = 0;
  museEEG = new float[5];
  for (int i=0; i<5; i++) museEEG[i] = 0;
  
  /* Hue 
  hub = new HueHub();
  light_1 = new HueLight(1, hub);
  light_2 = new HueLight(2, hub);
  light_3 = new HueLight(3, hub);
  */
  // ready to begin
  ready = true;
  
}

void draw() {
  background(50);
  fill(255,0,0);
  text("MUSE", 10,30);
  
  fill(255);
  
  // MUSE
  if (doMuse) {
    /* display data */
    text("eeg_output_frequency_hz", 10, 60);
    text(eeg_output_frequency_hz, 250, 60);
    text("battery_percent_remaining", 10,80);
    text(battery_percent_remaining, 250,80);
    text("notch_frequency_hz ", 10,100);
    text(notch_frequency_hz, 250,100);
    text("eeg: dropped_samples", 10,120);
    text(dropped_samples, 250,120);
    text("status_indicator ", 10, 140);
    text(status_indicator[0] + " " + status_indicator[1] + " " + status_indicator[2] + " " + status_indicator[3], 250, 140);

    for(int i=0; i<5; i++) {
      text(museEEGband[i], 10, 160+i*20);
      text(museEEG[i], 10+235, 160+i*20);
    }
  }

  // client address
  /*
  fill(255,0,0);
  text("OSC CLIENTS", 10, 330);
  fill(255);
  for(int i=0; i<myNetAddressList.size(); i++ ) {
    text(myNetAddressList.get(i).address(), 10, 350+i*20, 70, 40);
  }
  */
}
 
void oscEvent(OscMessage theOscMessage) {
  hub = new HueHub();
  light_1 = new HueLight(1, hub);
  light_2 = new HueLight(2, hub);
  light_3 = new HueLight(3, hub);
  float value;
//  println("broadcaster: oscEvent");
  if (ready) {

  /* check if the address pattern fits any of our patterns */
  if (theOscMessage.addrPattern().equals(myConnectPattern)) {
    connect(theOscMessage.netAddress().address());
  }
  else if (theOscMessage.addrPattern().equals(myDisconnectPattern)) {
    disconnect(theOscMessage.netAddress().address());
  }

  if(doMuse && theOscMessage.addrPattern().length()>4 && 
    theOscMessage.addrPattern().substring(0,5).equals("/muse")) {
  
    if (theOscMessage.addrPattern().equals("/muse/config")) {
      String config_json = theOscMessage.get(0).stringValue();
      JSONObject jo = JSONObject.parse(config_json);
      // println("config: " + jo.getString("mac_addr"));
      eeg_output_frequency_hz = jo.getInt("eeg_output_frequency_hz");
      notch_frequency_hz = jo.getInt("notch_frequency_hz");
      battery_percent_remaining = jo.getInt("battery_percent_remaining");
      // println(theOscMessage.addrPattern() + ": " + config_json);
    }
    else if (theOscMessage.addrPattern().equals("/muse/annotation")) {
      println(theOscMessage.addrPattern());
      for (int i=0; i<5; i++) println(theOscMessage.get(i).stringValue());
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/horseshoe")) {
      for (int i=0; i<4; i++) status_indicator[i] = int(theOscMessage.get(i).floatValue());
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/eeg/dropped_samples")) {
      dropped_samples = theOscMessage.get(0).intValue();
    }
    else if (theOscMessage.addrPattern().equals("/muse/eeg")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }  
    else if (theOscMessage.addrPattern().equals("/muse/eeg/quantization")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/acc")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/delta_absolute")) {
      museEEG[0] = (theOscMessage.get(1).floatValue());
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/theta_absolute")) {
      museEEG[1] = (theOscMessage.get(1).floatValue());
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/alpha_absolute")) {
      museEEG[2] = (theOscMessage.get(1).floatValue());
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/beta_absolute")) {
      museEEG[3] = (theOscMessage.get(1).floatValue());
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/gamma_absolute")) {
      museEEG[4] = (theOscMessage.get(1).floatValue());
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/blink")) {
      oscP5.send(theOscMessage, myNetAddressList);
      int blinkVal = theOscMessage.get(0).intValue();
      // println("muse blink "+blinkVal);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/jaw_clench")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/raw_fft0")) {
      value = theOscMessage.get(0).floatValue();
      println("Value is: " + value);
      // turn on alpha
      if (value > 0 && value <= 12) {
        light_1.turnOn(46920, 255, 255, 100);
        light_2.turnOn(46920, 255, 255, 10);
        light_3.turnOn(46920, 255, 255, 100);
      }
      // turn on beta 1
      else if (value > 12 && value <= 15) {
        light_1.turnOn(36210, 255, 255, 10);
        light_2.turnOn(36210, 255, 255, 10);
        light_3.turnOn(36210, 255, 255, 10);
      }
      // turn on beta 2
      else if (value > 15 && value <= 18) {
        light_1.turnOn(12750, 255, 255, 10);
        light_2.turnOn(12750, 255, 255, 10);
        light_3.turnOn(12750, 255, 255, 10);
      }
      // turn on beta 3
      else if (value > 18 && value <= 26) {
        light_1.turnOn(56100, 255, 255, 10);
        light_2.turnOn(56100, 255, 255, 10);
        light_3.turnOn(56100, 255, 255, 10);
      }
      // turn on beta 4
      else if (value > 26 && value <= 38) {
        light_1.turnOn(65280, 255, 255, 10);
        light_2.turnOn(65280, 255, 255, 10);
        light_3.turnOn(65280, 255, 255, 10);
      }
      // finding brainwave...
      else {
        light_1.turnOn(25500, 20, 200, 10);
        light_2.turnOn(25500, 20, 200, 10);
        light_3.turnOn(25500, 20, 200, 10);
      }
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/raw_fft1")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/raw_fft2")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }
    else if (theOscMessage.addrPattern().equals("/muse/elements/raw_fft3")) {
      oscP5.send(theOscMessage, myNetAddressList);
    }
    
  } else {
    println(theOscMessage.addrPattern());
  }
  }
}

// connect function
private void connect(String theIPaddress) {
  if (!myNetAddressList.contains(theIPaddress, myBroadcastPort)) {
     myNetAddressList.add(new NetAddress(theIPaddress, myBroadcastPort));
     println("### adding "+theIPaddress+" to the list.");
  } else {
     println("### "+theIPaddress+" is already connected.");
  }
  println("### currently there are "+myNetAddressList.list().size()+" remote locations connected.");
}


// disconnect function
private void disconnect(String theIPaddress) {
  if (myNetAddressList.contains(theIPaddress, myBroadcastPort)) {
    myNetAddressList.remove(theIPaddress, myBroadcastPort);
    println("### removing "+theIPaddress+" from the list.");
  } else {
    println("### "+theIPaddress+" is not connected.");
  }
  println("### currently there are "+myNetAddressList.list().size());
}


/* Hue bulbs */
/*
  - url to get 'id' and 'internalipaddress'
    https://www.meethue.com/api/nupnp
  - url to access bulbs with api
    <ipaddress>/debug/clip.html
*/

class HueHub {
  // url format - http://<IP>/api/<USERNAME>/light/<id>/state
  
  private static final String USERNAME = "newdeveloper";  // hue username for bulb interaction
  private static final String IP = "192.168.1.11";   // IP address of hub
  
  private DefaultHttpClient httpClient;  // http client to send/recieve data
  
  // constructor
  public HueHub() {
    httpClient = new DefaultHttpClient();
  }
  
  // apply state of hue light
  public void applyState(HueLight light) {
    try {
      // build url
      StringBuilder url = new StringBuilder("http://");
      url.append(IP);
      url.append("/api/");
      url.append(USERNAME);
      url.append("/lights/");
      url.append(light.getID());
      url.append("/state");
    
      // get light's data
      String data = light.getData();
      StringEntity stringEnt = new StringEntity(data);
      HttpPut httpPut = new HttpPut(url.toString());
      httpPut.setEntity(stringEnt);
    
      // send data to url
      HttpResponse response = httpClient.execute(httpPut);
      HttpEntity entity = response.getEntity();
    
      // release conection for next put
      if(entity != null) entity.consumeContent();
    }catch(Exception e){
      e.printStackTrace();
    }
  }
  
  // disconnect connection
  public void disconnect() {
    httpClient.getConnectionManager().shutdown();
  } 
}

class HueLight {
  private int id;  // light number (1,2, or 3)
  // light values
  private int hue = 30000;       // hue value, represents color
  private int saturation = 255;  // saturation value
  private int brightness = 255;  // brightness value
  private boolean lightOn = false;  // is light on?
  private int transitionTime = 0;  // transition time, how fast is light change occuring (1=0.1s)
  // hub
  private HueHub hub;  // where to register
  
  // constructor
  public HueLight(int lightID, HueHub aHub) {
    id = lightID;
    hub = aHub;
  }
  
  /* sets */
  
  // set hue value (color 0-65532)
  public void setHue(int hueValue) {
    if(hueValue < 0 || hueValue > 65532) {
      hue = 0;
    }else{
      hue = hueValue;
    }
  }
  
  // set brightness (1-255)
  public void setBrightness(int bri) {
    if(bri < 1 || bri > 255) {
      brightness = 250;
    }else{
      brightness = bri;
    }
  }
  
  // set saturation (1-255)
  public void setSaturation(int sat) {
    if(sat < 1 || sat > 255) {
      saturation = 250;
    }else{
      saturation = sat;
    }
    
    
  }
  
  // set transition time (1=0.1s) ..max?
  public void setTransitionTime(int transTime) {
    transitionTime = transTime;
  }
  
  /* gets */
  
  // get data
  public String getData() {
    StringBuilder data = new StringBuilder("{");
    data.append("\"on\":");
    data.append(lightOn);
    if(lightOn) {
      data.append(", \"hue\":");
      data.append(hue);
      data.append(", \"bri\":");
      data.append(brightness);
      data.append(", \"sat\":");
      data.append(saturation);
    }
    data.append(", \"transitiontime\":");
    data.append(transitionTime);
    data.append("}");
    
    return data.toString();
  }
  
  // get hue
  public int getHue() { return hue; }
  // get brightness
  public int getBrightness() { return brightness; }
  // get saturation
  public int getSaturation() { return saturation; }
  // get id
  public int getID() { return id; }
  
  // progress through colors
  public void incHue() {
    setHue(hue+=2000);
  }
  
  // check if light is on, true if light is on
  public boolean isOn() {
    return lightOn;
  }
  
  // update light state
  public void update() {
    hub.applyState(this);
  }
  
  // turn off light
  public void turnOff() {
    lightOn = false;
    update();
  }
  
  // turn on light
  public void turnOn() {
    lightOn = true;
    update();
  }
  
  // turn on light w/ values
  public void turnOn(int hueValue, int bri, int sat, int transTime) {
    lightOn = true;
    setHue(hueValue);
    setBrightness(bri);
    setSaturation(sat);
    setTransitionTime(transTime);
    update();
  }
}
