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
  0 => int loop_in_8bar;
  0 => int loop_out_8bar;
  0 => buf.play;
  int nr;
  0 => int wait_id;

  fun void connect(int i) {
    i => nr;
    //buf => dac;
    //buf => Gain g => dac;
    //0.5 => g.gain;
    0 => buf.channel;
    buf => dac.chan(nr*2);
    1 => buf.channel;
    buf => dac.chan(nr*2+1);
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
    0 => loop;
    0 => loop_in;
    0 => loop_out;
    0 => loop_in_8bar;
    0 => loop_out_8bar;
  }

  fun void qseek(int b8) {
    (b8*eightbar_samples()+eightbar_offset())$int => buf.pos;
    1 => buf.play;
  }

  fun void seek(int b8) {
    b8*eightbar_samples()$int => buf.pos;
    1 => buf.play;
  }

  fun void wait(int b8) {
    if (buf.play() == 1) {
      xmit.startMsg( "/next", "ii" );
      nr => xmit.addInt;
      b8 => xmit.addInt;
      while ((buf.pos() % eightbar_samples())$int != 0) { samp => now; }
    }
    seek(b8);
    xmit.startMsg( "/next/off", "i" );
    nr => xmit.addInt;
    0 => wait_id;
  }

  fun void bseek(int b8) {
    if (wait_id != 0) { Machine.remove(wait_id); }
    (spork ~ wait(b8)).id() => wait_id; 
  }

  fun void looping(int l) {
    l => loop;
    xmit.startMsg( "/loop", "ii" );
    nr => xmit.addInt;
    loop => xmit.addInt;
  }
  fun int getloop() { return loop; }
  fun int getloop_in() { return loop_in_8bar; }
  fun int getloop_out() { return loop_out_8bar; }

  fun void setloop_in(int eightbars) {
    eightbars => loop_in_8bar;
    8*ticks_bar*ticksamples()$int*eightbars => loop_in;
    xmit.startMsg( "/loop/in", "ii" );
    nr => xmit.addInt;
    eightbars => xmit.addInt;
  }

  fun void setloop_out(int eightbars) {
    eightbars => loop_out_8bar;
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
  fun float next_8bar_offset() { return (eightbars()+1)*eightbar_samples() - buf.pos(); }
  fun float bar_offset() { return buf.pos() - bars() * ticks_bar*ticksamples(); }
  fun float tick_offset() { return buf.pos() - ticks() * ticksamples(); }
}

// stems
Stem stems[4]; 
for (0=>int i; i<4; i++) { stems[i].connect(i); }
stems @=> Stem selected[];
"bseek" => string mode;

fun void stop() { for (0=>int i; i<4; i++) { stems[i].stop(); } }
fun void rate(float r) { for (0=>int i; i<4; i++) { stems[i].rate(r); } }
fun void seek(int b8) { for (0=>int i; i<selected.cap(); i++) { selected[i].seek(b8); } }
fun void qseek(int b8) { for (0=>int i; i<selected.cap(); i++) { selected[i].qseek(b8); } }
fun void bseek(int b8) { for (0=>int i; i<selected.cap(); i++) { selected[i].bseek(b8); } }

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
      else if (msg.address == "/stop") { stop(); }
    }
  }
}
sendcc(0,0); // reset
sendcc(0,40); // LED flashing

fun void update_launchpad() {
  // first row
  sendcc(104,29);
  sendcc(105,29);
  sendcc(106,13);
  sendcc(108,29);
  sendcc(109,12);
  if (mode == "bseek") { sendcc(104,60); }
  else if (mode == "qseek") { sendcc(105,60); }
  else if (mode == "seek") { sendcc(106,60); }
  else if (mode == "loopin") { sendcc(108,13); }
  else if (mode == "loopout") { sendcc(108,13); }

  // grid
  int col;
  int row;
  for (0=>int i; i<64; i++) {
    i%8 => col;
    i/8 => row;
    if (i<stems[0].eightbar_size()) { sendnote(16*row+col,29); }
    else { sendnote(16*row+col,12); }
  }
  for (0=>int i; i<selected.size(); i++) {
    selected[i].eightbars()$int %8 => col;
    selected[i].eightbars()$int /8 => row;
    if (selected[i].getloop() == 1) {
      for (selected[i].getloop_in()=>int j; j < selected[i].getloop_out();j++) {
        j %8 => int c;
        j /8 => int r;
        sendnote(16*r+c,13);
      }
    }
    sendnote(16*row+col,60);
  }
  for (0=>int i; i<4; i++) {
    if (selected.cap() == 1 && stems[i] == selected[0]) { sendnote(i*16+8,28); }
    else { sendnote(i*16+8,29); }
  }
  for (0=>int i; i<selected.size(); i++) {
    if (selected[i].loop == 1) { sendcc(109,28); }
  }
  sendnote(104,28); // D
  sendnote(120,13); // H
}

fun void loop_off() {
  for (0=>int i; i<selected.size(); i++) { selected[i].looping(0); } 
}

fun void view_launchpad() {
  while (true) {
    update_launchpad();
    bar_samples()::samp => now; 
  }
}

fun void launchpad() {
  while ( true ) {

    midiin => now;

    while( midiin.recv(inmsg) ) {

      if (inmsg.data1 == 144) { // note

        inmsg.data2%16 => int col;
        inmsg.data2/16 => int row;
        
        if (col < 8) { // grid
          if (inmsg.data3 == 127) { // press
            if (mode == "qseek") { qseek(8*row+col); }
            else if (mode == "bseek") { bseek(8*row+col); }
            else if (mode == "seek") { if (selected.cap() == 4) {seek(8*row+col);} }
            else if (mode == "loopin") {
              for (0=>int i; i<selected.cap(); i++) { selected[i].looping(0); }
              for (0=>int i; i<selected.cap(); i++) { selected[i].setloop_in(8*row+col); }
              "loopout" => mode;
            }
            else if (mode == "loopout") {
              for (0=>int i; i<selected.cap(); i++) { selected[i].setloop_out(8*row+col+1); }
              for (0=>int i; i<selected.cap(); i++) { selected[i].looping(1); }
              "bseek" => mode;
            }
          }
        }
        else if (col == 8) { // A-H
          if (row < 4) {  // A-D, banks
            if (inmsg.data3 == 127) {
              if (selected.cap() == 1 && stems[row] == selected[0]) {
                stems @=> selected;
                xmit.startMsg( "/select/all");
              }
              else {
                [stems[row]] @=> selected;
                xmit.startMsg( "/select", "i" );
                row => xmit.addInt;
              }
            }
          }
          else if (row == 5) { // E
          }
          else if (row == 6) { // F
            if (inmsg.data3 == 127) { rate(1.02); } // press
            else if (inmsg.data3 == 0) { rate(1.0); } // release
          }
          else if (row == 7) { // H
            if (inmsg.data3 == 127) { rate(0.98); } // press
            else if (inmsg.data3 == 0) { rate(1.0); } // release
          }
        }
      }

      else if (inmsg.data1 == 176) {
        inmsg.data2-104 => int i;
        if (inmsg.data3 == 127) { // 1-8 press
          if (i == 0) { "bseek" => mode; }
          else if (i == 1) { "qseek" => mode; }
          else if (i == 2) { "seek" => mode; }
          else if (i == 4) { "loopin" => mode; }
          else if (i == 5) { loop_off(); }
        }
        else if (inmsg.data3 == 0) { // 1-8 release
          if (i == 2) { "bseek" => mode; }
        }
      }
    }
    update_launchpad();
  }
}

for (0=>int i; i<4; i++) {
  spork ~ stems[i].position();
  spork ~ stems[i].looper();
}

spork ~ view_launchpad();
spork ~ osc();
launchpad();
