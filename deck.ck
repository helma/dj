132.0 => float bpm;
1.0 => float rate;
0 => int ticks;
0 => int quant;

Event tick;
Event bar;
Event eightbar;

OscIn oin;
9668 => oin.port;
OscMsg msg;
oin.listenAll();

SndBuf2 buffer; 
buffer => dac;
0 => buffer.play;

fun dur tickdur() { return 15::second/(bpm*rate); }
 
fun void ticker() {

  OscSend osend;
  osend.setHost("localhost",9669);

  while (true) {
    if (buffer.play() == 1) { 
      tick.broadcast();
      if (ticks % 16 == 0) { bar.broadcast(); }
      if (ticks % (16*8) == 0) { eightbar.broadcast(); }
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
      0 => buffer.play;
      msg.getString(0) => buffer.read;
      0 => buffer.pos;
      0 => ticks;
      1 => rate;
    }
    else if (msg.address == "/play") {
      msg.getInt(1) => quant;
      if (buffer.play() == 0) { 1 => buffer.play; }
      else if (quant == 1) { tick => now; }
      else if (quant == 2) { bar => now; }
      else if (quant == 3) { eightbar => now; }
      msg.getInt(0) => ticks;
      44100*ticks*15/(bpm*rate) $ int => buffer.pos;
      1 => buffer.play;
    }
    else if (msg.address == "/rate") {
      tickdur() => now;
      msg.getFloat(0) => rate;
      msg.getFloat(0) => buffer.rate;
    }
    else if (msg.address == "/stop") {
      0 => ticks;
      tickdur() => now;
      0 => buffer.play;
      0 => buffer.pos;
      1 => rate;
    }
  }
}
