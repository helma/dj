132.0 => float bpm;
1.0 => float rate;
0 => int ticks;
0 => int quant;

Event tick;

OscIn oin;
9668 => oin.port;
OscMsg msg;
oin.listenAll();

SndBuf2 buffer; 
buffer => dac;
0 => buffer.play;

fun dur tickdur() {
  return 15::second/(bpm*rate);
}
 
fun void ticker() {

  OscSend osend;
  osend.setHost("localhost",9669);

  while (true) {
    if (buffer.play() == 1) { 
      tick.broadcast();
      osend.startMsg("/sixteenth","i");
      osend.addInt(ticks);
      ticks + 1 => ticks; 
    }
    tickdur() => now;
  }
}

spork ~ ticker();

while ( true ) {
  oin => now;
  while ( oin.recv(msg) != 0 ) { 
    if (msg.address == "/read") {
  <<< msg.address >>>;
      0 => buffer.play;
      msg.getString(0) => buffer.read;
      0 => buffer.pos;
      0 => ticks;
      1 => rate;
    }
    else if (msg.address == "/play") {
      msg.getInt(1) => quant;
      msg.getInt(0) => ticks;
      quant*tickdur() => now;
      (ticks*15/(bpm*rate)) $ int => buffer.pos;
      1 => buffer.play;
    }
    else if (msg.address == "/rate") {
      tickdur() => now;
      msg.getFloat(0) => rate;
      msg.getFloat(0) => buffer.rate;
    }
  }
}
