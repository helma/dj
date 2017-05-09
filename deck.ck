/* TODO
play/loop 16th and restart at correct position
*/
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

// files
string files[8];
FileIO fio;
fio.open("/home/ch/music/live/dj/playlist.m3u", FileIO.READ);
0 => int nr_files;
while( fio.more() && nr_files < 8 ) {
  fio.readLine() => files[nr_files];
  sendcc(nr_files+104,29);
  nr_files+1 => nr_files;
}

// buffer
SndBuf2 buffer; 
0 => buffer.play;
buffer => dac;

132.0 => float bpm;
1 => int quant;

0 => int led_16th;
0 => int last16th;
0 => int led_bars;
0 => int lastbar;
0 => int led_8bars;
0 => int last8;

fun dur tickdur() { return 15::second/bpm; }
fun int ticksamples() { return 44100*15/bpm $ int; }

fun float ticks() { return bpm*buffer.pos()/44100/15; }
fun float bars() { return ticks()/16; }
fun float eightbars() { return ticks()/128; }

fun int eightbar_offset() { return buffer.pos() - eightbars()$int * 128*ticksamples(); }
fun int bar_offset() { return buffer.pos() - bars()$int * 16*ticksamples(); }
fun int tick_offset() { return buffer.pos() - ticks()$int * ticksamples(); }

fun int nr_8bars() { return Math.ceil(bpm*buffer.samples()/(8*240*44100)) $ int; }

fun void reset() {
  0 => buffer.play;
  0 => buffer.pos;
  0 => int quant;
  0 => int n;

  0 => int led_16th;
  0 => int last16th;
  0 => int led_bars;
  0 => int lastbar;
  0 => int led_8bars;
  0 => int last8;
  for (0 => int r; r < 5; r++) {
    for (0 => int c; c < 8; c++) {
      if (n <= nr_8bars()) { sendnote(16*r+c,29); }
      else { sendnote(16*r+c,12); }
      n++;
    }
  }
  sendnote(0,60);
}

fun void seek(int ticks, int offset) {
  (44100*15*ticks/bpm)$int + offset => buffer.pos;
  1 => buffer.play;
}

sendnote(72,28);
sendnote(88,13);
sendnote(120,62);

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

fun void controller() {

  0 => int pos;
  0 => int offset;
  0 => int lasttrack;

  while ( true ) {

    midiin => now;

    while( midiin.recv(inmsg) ) {

      if (inmsg.data1 == 144) { // note

        inmsg.data2%16 => int col;
        inmsg.data2/16 => int row;
        
        if (col < 8) { // grid
          if (inmsg.data3 == 127) { // press
            if (row < 5) {  // eightbars
              128*(8*row+col) => pos;
              if (quant == 0) { seek(pos,0); }
              else { seek(pos,eightbar_offset()); }
            }
            if (row > 5 && quant == 1) { // 16th
              16*bars()$int+8*(row-6)+col => pos;
              seek(pos,tick_offset());
            }
          }
        }

        else if (col == 8) { // A-H
          if (row < 4) { // A-D, banks
          }
          else if (row == 4) { // E
            if (inmsg.data3 == 127) { 1.04 => buffer.rate; } // press
            else if (inmsg.data3 == 0) { 1 => buffer.rate; } // release
          }
          else if (row == 5) { // F
            if (inmsg.data3 == 127) { 0.96 => buffer.rate; } // press
            else if (inmsg.data3 == 0) { 1 => buffer.rate; } // release
          }
          else if (row == 7) { // H
            if (inmsg.data3 == 127) { 0 => quant; } // press
            else if (inmsg.data3 == 0) { 1 => quant; } // release
          }
        }
      }

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

    }
  }
}

spork ~ view();
spork ~ controller();

while (true) { minute => now; }
