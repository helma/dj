// OSC
OscSend xmit;
xmit.setHost( "localhost", 9090);

// stems
SndBuf2 stems[4]; 
for (0=>int i; i<4; i++) { 
  0 => stems[i].play;
  0 => stems[i].channel;
  stems[i] => dac.chan(i*2);
  1 => stems[i].channel;
  stems[i] => dac.chan(i*2+1);
}

132.0 => float bpm;
8 => int ticks_bar;
0 => int loop;
0 => int loop_in;
0 => int loop_out;

fun float tickratio() { return 240/ticks_bar/bpm; }
fun dur tickdur() { return 1::second*tickratio(); }
fun float ticksamples() { return 44100*tickratio(); }

fun float ticks() { return stems[0].pos()/ticksamples(); }
fun float bars() { return ticks()/ticks_bar; }
fun float eightbars() { return ticks()/8/ticks_bar; }

fun int eightbar_offset() { return stems[0].pos() - eightbars()$int * 8*ticks_bar*ticksamples()$int; }
fun int bar_offset() { return stems[0].pos() - bars()$int * ticks_bar*ticksamples()$int; }
fun int tick_offset() { return stems[0].pos() - ticks()$int * ticksamples()$int; }

fun void stop() {
  for (0=>int i; i<4; i++) {
    0 => stems[i].play;
    0 => stems[i].pos;
  }
  0 => int loop;
  0 => int loop_in;
  0 => int loop_out;
}

fun void seek(int ticks, int offset) {
  for (0=>int i; i<4; i++) { 
    (ticks*ticksamples())$int + offset => stems[i].pos;
    1 => stems[i].play;
  }
}

fun void rate(float r) { for (0=>int i; i<4; i++) { r => stems[i].rate; } }

fun void position() {
<<< "OSC pos" >>>;
  while (true) {
    if (stems[0].play() == 1) {
      xmit.startMsg( "/phase", "f" );
      stems[0].phase() => xmit.addFloat;
    }
    30::ms => now; // ~ 30fps
  }
}

fun void looper() {
<<< "looper" >>>;
  while (true) {
    if (loop == 1 && loop_out > loop_in) {
      if (stems[0].pos() >= loop_out) {
        for (0=>int i; i<4; i++) { loop_in => stems[i].pos; }
      }
    }
    1::samp => now;
  }
}

fun void controller() {
<<< "controller" >>>;

  OscIn oin;
  9091 => oin.port;
  oin.listenAll();

  OscMsg msg;

  while(true) {
    oin => now;
    while(oin.recv(msg)) {
      if (msg.address == "/load") {
        stop();
        msg.getString(0) => string dir;
        for (0=>int s; s<4; s++) {
          dir + "/" + s + ".wav" => string file;
          file => stems[s].read;
        }
      }
      else if (msg.address == "/goto/8bar/quant") {
        seek(8*ticks_bar*msg.getInt(0),eightbar_offset());
      }
      else if (msg.address == "/goto/8bar") {
        seek(8*ticks_bar*msg.getInt(0),0);
      }
      else if (msg.address == "/loop/on") { 1 => loop; }
      else if (msg.address == "/loop/off") { 0 => loop; }
      else if (msg.address == "/loop/set/8bar") {
        8*ticks_bar*ticksamples()$int*msg.getInt(0) => loop_in;
        8*ticks_bar*ticksamples()$int*msg.getInt(1) => loop_out;
      }
      else if (msg.address == "/speed/up") { rate(1.04); }
      else if (msg.address == "/speed/down") { rate(0.96); }
      else if (msg.address == "/speed/normal") { rate(1.0); }
      else if (msg.address == "/stop") { stop(); }
    }
  }
}

spork ~ position();
spork ~ looper();
controller();
