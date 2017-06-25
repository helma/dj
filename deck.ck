// OSC
OscSend xmit;
xmit.setHost( "localhost", 9090);

132.0 => float bpm;
8 => int ticks_bar;

fun float tickratio() { return 240/ticks_bar/bpm; }
fun dur tickdur() { return 1::second*tickratio(); }
fun float ticksamples() { return 44100*tickratio(); }
fun int bar_samples() { return ticks_bar*ticksamples() $ int; }
fun int eightbar_samples() { return 8*ticks_bar*ticksamples() $ int; }

class Stem {

  SndBuf2 buf;
  0 => int loop;
  0 => int loop_in;
  0 => int loop_out;
  0 => buf.play;
  int nr;

  fun void connect(int i) {
    i => nr;
    //buf => dac;
    buf => Gain g => dac;
    0. => g.gain;
    //0 => buf.channel;
    //buf => dac.chan(nr*2);
    //1 => buf.channel;
    //buf => dac.chan(nr*2+1);
  }

  fun void read(string file) {
    stop();
    file => buf.read;
  }

  fun void stop() {
    0 => buf.play;
    0 => buf.pos;
    0 => int loop;
    0 => int loop_in;
    0 => int loop_out;
  }

  fun void seek(int samples) {
      samples => buf.pos;
      1 => buf.play;
  }

  fun void setloop(int l) {
    l => loop;
    xmit.startMsg( "/loop", "ii" );
    nr => xmit.addInt;
    loop => xmit.addInt;
  }

  fun void setloop_in(int eightbars) {
    8*ticks_bar*ticksamples()$int*eightbars => loop_in;
    xmit.startMsg( "/loop/in", "ii" );
    nr => xmit.addInt;
    eightbars => xmit.addInt;
  }

  fun void setloop_out(int eightbars) {
    8*ticks_bar*ticksamples()$int*eightbars => loop_out;
    xmit.startMsg( "/loop/out", "ii" );
    nr => xmit.addInt;
    eightbars => xmit.addInt;
  }

  fun void nextbar(int eightbar) {
    next_bar_offset()::samp => now;
    seek(eightbar*eightbar_samples());
  }

  fun void rate(float r) { r => buf.rate; }

  fun void position() {
    while (true) {
      if (buf.play() == 1) {
        xmit.startMsg( "/phase", "if" );
        nr => xmit.addInt;
        buf.phase() => xmit.addFloat;
      }
      30::ms => now; // ~ 30fps
    }
  }

  fun void looper() {
    while (true) {
      if (loop == 1 && loop_out > loop_in) {
        if (buf.pos() == loop_out) { loop_in => buf.pos; }
      }
      1::samp => now;
    }
  }

  fun float ticks() { return buf.pos()/ticksamples(); }
  fun float bars() { return ticks()/ticks_bar; }
  fun float eightbars() { return ticks()/8/ticks_bar; }

  fun int eightbar_offset() { return buf.pos() - eightbars()$int * eightbar_samples(); }
  fun int next_bar_offset() { return (bars()$int+1)*bar_samples() - buf.pos(); }
  fun int bar_offset() { return buf.pos() - bars()$int * ticks_bar*ticksamples()$int; }
  fun int tick_offset() { return buf.pos() - ticks()$int * ticksamples()$int; }
}

// stems
Stem stems[4]; 
for (0=>int i; i<4; i++) { stems[i].connect(i); }

fun void stop() { for (0=>int i; i<4; i++) { stems[i].stop(); } }
fun void seek(int samples) { for (0=>int i; i<4; i++) { stems[i].seek(samples); } }
fun void rate(float r) { for (0=>int i; i<4; i++) { stems[i].rate(r); } }

fun void controller() {

  OscIn oin;
  9091 => oin.port;
  oin.listenAll();

  OscMsg msg;

  while(true) {
    oin => now;
    while(oin.recv(msg)) {
      if (msg.address == "/read") {
        stems[msg.getInt(0)].read(msg.getString(1));
      }
      else if (msg.address == "/goto/8bar/quant") {
        msg.getInt(0) => int i;
        stems[i].seek(msg.getInt(1)*eightbar_samples()+stems[i].eightbar_offset());
      }
      else if (msg.address == "/goto/8bar/next") {
        msg.getInt(0) => int i;
        spork ~ stems[i].nextbar(msg.getInt(1));
      }
      else if (msg.address == "/goto/8bar/now") {
        msg.getInt(0) => int i;
        stems[i].seek(msg.getInt(1)*eightbar_samples());
      }
      else if (msg.address == "/loop") {
        msg.getInt(0) => int i;
        stems[i].setloop(msg.getInt(1));
      }
      else if (msg.address == "/loop/in") {
        msg.getInt(0) => int i;
        stems[i].setloop_in(msg.getInt(1));
      }
      else if (msg.address == "/loop/out") {
        msg.getInt(0) => int i;
        stems[i].setloop_out(msg.getInt(1));
      }
      else if (msg.address == "/speed/up") { rate(1.02); }
      else if (msg.address == "/speed/down") { rate(0.98); }
      else if (msg.address == "/speed/normal") { rate(1.0); }
      else if (msg.address == "/stop") { stop(); }
    }
  }
}

for (0=>int i; i<4; i++) {
  spork ~ stems[i].position();
  spork ~ stems[i].looper();
}

controller();
