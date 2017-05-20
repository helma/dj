// TODO fix duplicated events
// midi
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

sendcc(0,0); // reset
sendcc(0,40); // LED flashing

sendnote(72,12); // E
sendnote(88,13); // F
sendnote(104,28); // G
sendnote(120,62); // H

// OSC
OscSend xmit;
xmit.setHost( "localhost", 9090);

// files
0 => int bank;
0 => int track;
"/home/ch/music/live/dj/" => string dir;

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
0 => int quant;
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

fun int nr_8bars() { return Math.ceil(stems[0].samples()/ticksamples()/8/ticks_bar) $ int; }

fun void stop() {
  for (0=>int i; i<4; i++) {
    0 => stems[i].play;
    0 => stems[i].pos;
  }
  0 => int quant;
  0 => int loop;
  0 => int loop_in;
  0 => int loop_out;
  for (0 => int r; r < 5; r++) { // clear track display
    for (0 => int c; c < 8; c++) { sendnote(16*r+c,12); }
  }
}

fun void seek(int ticks, int offset) {
  for (0=>int i; i<4; i++) { 
    (ticks*ticksamples())$int + offset => stems[i].pos;
    1 => stems[i].play;
  }
}

fun void rate(float r) { for (0=>int i; i<4; i++) { r => stems[i].rate; } }

fun void view() {
<<< "view" >>>;
  while (true) {

    ticks()$int % ticks_bar + 112 => int led_ticks;
    for (112 => int n; n < 120; n++) {
      if (n == led_ticks) { sendnote(n,60); }
      else { sendnote(n,12); }
    }

    bars()$int % 8 + 96 => int led_bars;
    for (96 => int n; n < 104; n++) {
      if (n == led_bars) { sendnote(n,60); }
      else { sendnote(n,12); }
    }

    eightbars()$int %8 => int col;
    eightbars()$int /8 => int row;
    16*row+col => int led_8bars;
    for (0 => int r; r < 6; r++) {
      for (0 => int c; c < 8; c++) {
        16*r+c => int n;
        if (n <= nr_8bars()) {
          if (n == led_8bars) { sendnote(led_8bars,60); }
          else { sendnote(n,29); }
        }
        else { sendnote(n,12); }
      }
    }
    tickdur() => now;
  }
}

fun void osc_position() {
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
    if (stems[0].pos() == loop_out) {
      for (0=>int i; i<4; i++) { loop_in => stems[i].pos; }
    }
  }
  1::samp => now;
  }
}

fun void controller() {
<<< "controller" >>>;

  0 => int nextpos;
  0 => int hold;
  while ( true ) {

    midiin => now;
    while( midiin.recv(inmsg) ) {

      if (inmsg.data1 == 144) { // note

        inmsg.data2%16 => int col;
        inmsg.data2/16 => int row;
        
        if (col < 8) { // grid
          if (row < 6) {  // eightbars
            8*ticks_bar*(8*row+col) => nextpos;
            if (inmsg.data3 == 127 && loop == 0) { // press
              if (quant == 0) { seek(nextpos,0); }
              else { seek(nextpos,eightbar_offset()); }
            }
            else if (inmsg.data3 == 127 && loop == 1) { // loop
              if (hold == 0) { nextpos => loop_in; 1 => hold; }
              else if (hold == 1) {
                if (nextpos > loop_in) { nextpos => loop_out; }
                else { loop_in => loop_out; nextpos => loop_in; }
                <<< loop_in, loop_out >>>;
                0 => hold;
                xmit.startMsg( "/loop, f, f" );
                loop_in/stems[0].samples() => xmit.addFloat;
                loop_out/stems[0].samples() => xmit.addFloat;
              }
            }
            else if (inmsg.data3 == 0 && loop == 1) { 0 => hold; } // release
          }
          if (row == 7 && quant == 1) { // ticks
            ticks_bar*bars()$int+8*(row-6)+col => nextpos;
            seek(nextpos,tick_offset());
          }
        }

        else if (col == 8) { // A-H
          if (row < 4) { // A-D, banks
            if (inmsg.data3 == 127) { // press
              row => bank;
              sendnote(inmsg.data2,29);
            }
          }
          else if (row == 4) { // E
            if (loop == 1) { 0 => loop; sendnote(inmsg.data2,12); }
            else { 1 => loop; sendnote(inmsg.data2,60); }
          }
          else if (row == 5) { // F
            if (inmsg.data3 == 127) { rate(1.04); } // press
            else if (inmsg.data3 == 0) { rate(1.0); } // release
          }
          else if (row == 6) { // F
            if (inmsg.data3 == 127) { rate(0.96); } // press
            else if (inmsg.data3 == 0) { rate(1.0); } // release
          }
          else if (row == 7) { // H
            if (inmsg.data3 == 127) { 0 => quant; } // press
            else if (inmsg.data3 == 0) { 1 => quant; } // release
          }
        }
      }

      else if (inmsg.data1 == 176 && inmsg.data3 == 127) { // 1-8 press
        inmsg.data2-104 => int t;
        stop();
        for (0=>int s; s<4; s++) {
          dir + bank + "/" + t + "/" + s + ".wav" => string file;
          file => stems[s].read;
        }
        0 => int n;
        for (0 => int r; r < 5; r++) {
          for (0 => int c; c < 8; c++) {
            if (n <= nr_8bars()) { sendnote(16*r+c,29); }
            n++;
          }
        }
        xmit.startMsg( "/load, i, i" );
        bank => xmit.addInt;
        t => xmit.addInt;
      }

    }
  }
}

spork ~ view();
spork ~ osc_position();
spork ~ looper();
controller();

//while (true) { minute => now; }
