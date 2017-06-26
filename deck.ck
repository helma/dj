// OSC
OscSend xmit;
xmit.setHost( "localhost", 9090);

132.0 => float bpm;
8 => int ticks_bar;

MidiIn midiin;
midiin.open(Std.atoi(me.arg(0)));
MidiMsg inmsg;
MidiOut midiout;
midiout.open(Std.atoi(me.arg(0)));
MidiMsg outmsg;

fun void sendcc(int d2,int d3) {
  176 => outmsg.data1;
  d2 => outmsg.data2;
  d3 => outmsg.data3;
  midiout.send(outmsg);
}

fun void sendnote(int d2,int d3) {
  144 => outmsg.data1;
  d2 => outmsg.data2;
  d3 => outmsg.data3;
  midiout.send(outmsg);
}

fun float tickratio() { return 240/ticks_bar/bpm; }
fun dur tickdur() { return 1::second*tickratio(); }
fun float ticksamples() { return 44100*tickratio(); }
fun float bar_samples() { return ticks_bar*ticksamples(); }
fun float eightbar_samples() { return 8*ticks_bar*ticksamples(); }

class Stem {

  SndBuf2 buf;
  0 => int loop;
  0 => int loop_in;
  0 => int loop_out;
  0 => buf.play;
  int nr;

  fun void connect(int i) {
    i => nr;
    buf => dac;
    //buf => Gain g => dac;
    //0. => g.gain;
    //0 => buf.channel;
    //buf => dac.chan(nr*2);
    //1 => buf.channel;
    //buf => dac.chan(nr*2+1);
  }

  fun int eightbar_size() {
    return (buf.samples()/eightbar_samples())$int;
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

  fun void qseek(int b8) {
  <<<  eightbar_offset()>>>;
    (b8*eightbar_samples()+eightbar_offset())$int => buf.pos;
    1 => buf.play;
  }

  fun void seek(int b8) {
    b8*eightbar_samples()$int => buf.pos;
    1 => buf.play;
  }

  fun void bseek(int b8) {
    next_bar_offset()::samp => now;
    seek(b8);
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
  fun int bars() { return (ticks()/ticks_bar)$int; }
  fun int eightbars() { return (ticks()/8/ticks_bar)$int; }

  fun float eightbar_offset() { return buf.pos() - eightbars() * eightbar_samples(); }
  fun float next_bar_offset() { return (bars()+1)*bar_samples() - buf.pos(); }
  fun float bar_offset() { return buf.pos() - bars() * ticks_bar*ticksamples(); }
  fun float tick_offset() { return buf.pos() - ticks() * ticksamples(); }
}

// stems
Stem stems[4]; 
for (0=>int i; i<4; i++) { stems[i].connect(i); }
stems @=> Stem selected[];

fun void stop() { for (0=>int i; i<4; i++) { stems[i].stop(); } }
fun void rate(float r) { for (0=>int i; i<4; i++) { stems[i].rate(r); } }
fun void seek(int b8) { for (0=>int i; i<selected.cap(); i++) { selected[i].seek(b8); } }
fun void qseek(int b8) { for (0=>int i; i<selected.cap(); i++) { selected[i].qseek(b8); } }
fun void bseek(int b8) { for (0=>int i; i<selected.cap(); i++) { spork ~ selected[i].bseek(b8); } }

fun void osc() {

  OscIn oin;
  9091 => oin.port;
  oin.listenAll();

  OscMsg msg;

  while(true) {
    oin => now;
    while(oin.recv(msg)) {
      if (msg.address == "/read") {
        msg.getInt(0) => int i;
        stems[i].read(msg.getString(1));
        update_launchpad();
      }
      else if (msg.address == "/8bar/quant") {
        msg.getInt(0) => int i;
        stems[i].qseek(msg.getInt(1));
      }
      else if (msg.address == "/8bar/next") {
        msg.getInt(0) => int i;
        spork ~ stems[i].bseek(msg.getInt(1));
      }
      else if (msg.address == "/8bar/now") {
        msg.getInt(0) => int i;
        stems[i].seek(msg.getInt(1));
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
sendcc(0,0); // reset
sendcc(0,40); // LED flashing
//0 => int pos;
//0 => int offset;
//0 => int lasttrack;
//0 => int selected;

//sendnote(72,28);
sendnote(88,28);
sendnote(104,13);
sendnote(120,62);

fun void update_launchpad() {
  int col;
  int row;
  for (0=>int i; i<64; i++) {
    i%8 => col;
    i/8 => row;
    if (i<stems[0].eightbar_size()) { sendnote(16*row+col,29); }
    else { sendnote(16*row+col,12); }
  }
  for (0=>int i; i<selected.size(); i++) {
    selected[i].eightbars() $ int %8 => col;
    selected[i].eightbars() $ int /8 => row;
    sendnote(16*row+col,60);
  }
}

fun void view_launchpad() {
  while (true) {
    update_launchpad();
    bar_samples()::samp => now; 
  }
}

/*
fun void view() {

  while (true) {
    if (buffer.play() == 1) { 

      ticks() $ int % 16 => led_16th;
      if (led_16th > 7) { led_16th + 104 => led_16th; }
      else { led_16th + 96 => led_16th; }
      if (last16th != led_16th) { sendnote(last16th,12); }
      sendnote(led_16th,60);
      led_16th => last16th;

      bars() $ int % 8 + 80 => led_bars;
      if ( lastbar != led_bars) { sendnote(lastbar,12); }
      sendnote(led_bars,60);
      led_bars => lastbar;

      eightbars() $ int %8 => int col;
      eightbars() $ int /8 => int row;
      16*row+col => led_8bars;
      if (eightbars() <= nr_8bars()) {
        if (last8 != led_8bars) { sendnote(last8,29); }
        sendnote(led_8bars,60);
        led_8bars => last8;
      }
      else { reset(); }
    }
    tickdur() => now;
  }
}
*/


fun void launchpad() {
  while ( true ) {

    midiin => now;

    while( midiin.recv(inmsg) ) {

      if (inmsg.data1 == 144) { // note

        inmsg.data2%16 => int col;
        inmsg.data2/16 => int row;
        
        if (col < 8) { // grid
          if (inmsg.data3 == 127) { qseek(8*row+col); } // press
        }
        else if (col == 8) { // A-H
          if (row < 4) {  // A-D, banks
            if (inmsg.data3 == 127) {
              [stems[row]] @=> selected;
              update_launchpad();
            }
            else if (inmsg.data3 == 0) {
              stems @=> selected;
              update_launchpad();
            }
          }
          else if (row == 5) { // E
            if (inmsg.data3 == 127) { rate(1.02); } // press
            else if (inmsg.data3 == 0) { rate(1.0); } // release
          }
          else if (row == 6) { // F
            if (inmsg.data3 == 127) { rate(0.98); } // press
            else if (inmsg.data3 == 0) { rate(1.0); } // release
          }
          else if (row == 7) { // H
            if (inmsg.data3 == 127) {
            //0.96 => buffer.rate;
            } // press
          }
        }
      }

  /*
      else if (inmsg.data1 == 176 && inmsg.data3 == 127) { // 1-8 press
        inmsg.data2-104 => int i;
        if (i < nr_files) {
          0 => buffer.play;
          files[i] => buffer.read;
          reset();
          sendcc(inmsg.data2,60);
          sendcc(lasttrack,29);
          inmsg.data2 => lasttrack;
        }
        else {
          sendcc(lasttrack,29);
          reset();
        }
      }
  */

    }
  }
}

for (0=>int i; i<4; i++) {
  spork ~ stems[i].position();
  spork ~ stems[i].looper();
}

spork ~ view_launchpad();
spork ~ osc();
launchpad();
