public class Deck {

  SndBuf2 buffer; 
  buffer => dac;
  0 => buffer.play;

Clock c;
spork ~ c.osc();

  fun void osc() {
    OscIn oin;
    9668 => oin.port;
    OscMsg msg;
    oin.listenAll();

    while ( true ) {
      oin => now;
      while ( oin.recv(msg) != 0 ) { 
        if (msg.address == "/read") {
          0 => buffer.play;
          msg.getString(0) => buffer.read;
          0 => buffer.pos;
        }
        else if (msg.address == "/play") {
          msg.getString(1) => string quant;
          <<< quant >>>;
          if (quant == "eightbars") { Clock._eightbars => now; }
          else if (quant == "bars") { Clock._bars => now; }
          else if (quant == "sixteenth") { Clock._sixteenth => now; }
          // TODO int? samples
          (msg.getFloat(0)*44100) $ int => buffer.pos;
          1 => buffer.play;
          <<< "play" >>>;
        }
        else if (msg.address == "/rate") {
          Clock._sixteenth => now;
          msg.getFloat(0) => buffer.rate;
        }
      }
    }
  }

}

Deck d;
spork ~ d.osc();

while(true) { minute => now; }
