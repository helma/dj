SndBuf2 buffer; 
buffer => dac;
0 => buffer.play;

Clock c;
spork ~ c.osc();

fun void deck_osc() {
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
        //if (quant == "eightbars") { c._eightbars => now; }
        //else if (quant == "bars") { c._bars => now; }
        //else if (quant == "sixteenth") { c._sixteenth => now; }
        // TODO int? samples
        (msg.getFloat(0)*44100) $ int => buffer.pos;
        1 => buffer.play;
        <<< "play" >>>;
      }
      else if (msg.address == "/rate") {
        c._sixteenth => now;
        msg.getFloat(0) => buffer.rate;
      }
    }
  }
}

spork ~ deck_osc();

while(true) { minute => now; }
