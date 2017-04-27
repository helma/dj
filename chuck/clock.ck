public class Clock {

  132.0 => static float bpm;
  1.0 => static float rate;
  0 => static int pulses;
  0 => int play;

  new Event @=> static Event @ _sixteenth;
  new Event @=> static Event @ _bars;
  new Event @=> static Event @ _eightbars;

  static Shred @ tick8bars;
  static Shred @ tickbars;
  static Shred @ tick16th;

//MidiOut mout;
//mout.open(2);


  OscSend osend;
  osend.setHost("localhost",9669);
 
  fun void eightbars() {
    while (true) {
      _eightbars.broadcast();
      osend.startMsg("/eightbars","i");
      osend.addInt(pulses/(8*16));
      8*240::second/(bpm*rate) => now;
    }
  }

  fun void bars() {
    while (true) {
      _bars.broadcast();
      osend.startMsg("/bars","i");
      osend.addInt(pulses/16);
      240::second/(bpm*rate) => now;
    }
  }
 
  fun void sixteenth() {
    while (true) {
      _sixteenth.broadcast();
      osend.startMsg("/sixteenth","i");
      osend.addInt(pulses);
      if (play == 1) { pulses + 1 => pulses; }
      15::second/(bpm*rate) => now;
    }
  }

  fun void osc() {

    OscIn oin;
    9668 => oin.port;
    OscMsg msg;
    oin.listenAll();

    spork ~ eightbars() @=> tick8bars;
    spork ~ bars() @=> tickbars;
    spork ~ sixteenth() @=> tick16th;

    while ( true ) {
      oin => now;
      while ( oin.recv(msg) ) { 
        if (msg.address == "/play") {
          msg.getString(1) => string quant;
          if (quant == "eightbars") { _eightbars => now; }
          else if (quant == "bars") { _bars => now; }
          else if (quant == "sixteenth") { _sixteenth => now; }
          else {
            <<< "unquant" >>>;
            tick8bars.exit();
            tickbars.exit();
            tick16th.exit();
            1 => play;
            spork ~ eightbars() @=> tick8bars;
            spork ~ bars() @=> tickbars;
            spork ~ sixteenth() @=> tick16th;
          }
          (msg.getFloat(0)/(15/(bpm*rate))) $ int => pulses;
        }
        else if (msg.address == "/read") {
          0 => play;
          0 => pulses;
        }
        else if (msg.address == "/rate") {
          15::second/(bpm*rate) => now;
          msg.getFloat(0) => rate;
        }
      }
    }
  }
}

//while(true) { minute => now; }
