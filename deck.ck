// midi
//Std.atoi(Std.getenv("LAUNCHPAD")) => int launchpad;
MidiIn midiin;
midiin.open(1);
MidiMsg inmsg;
MidiOut midiout;
midiout.open(1);
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
  sendcc(nr_files+103,29);
  nr_files+1 => nr_files;
}
nr_files-1 => nr_files;

// buffer
SndBuf2 buffer; 
0 => buffer.play;
buffer => dac;

// events
Event tick;
Event bar;
Event eightbar;

132.0 => float bpm;
1.0 => float rate;
0 => int ticks;
0 => int bars;
0 => int eightbars;
0 => int quant;
0 => int nr_8bars;

0 => int led_16th;
0 => int last16th;
0 => int led_bars;
0 => int lastbar;
0 => int led_8bars;
0 => int last8;

fun dur tickdur() { return 15::second/(bpm*rate); }

fun void setrate(float r) {
  tickdur() => now;
  r => rate;
  r => buffer.rate;
}

fun void reset() {
  0 => buffer.play;
  0 => buffer.pos;
  0 => int ticks;
  0 => int bars;
  0 => int eightbars;
  0 => int quant;
  0 => int n;

  0 => int led_16th;
  0 => int last16th;
  0 => int led_bars;
  0 => int lastbar;
  0 => int led_8bars;
  0 => int last8;
  for (0 => int r; r < 4; r++) {
    for (0 => int c; c < 8; c++) {
      if (n <= nr_8bars) { sendnote(16*r+c,29); }
      else { sendnote(16*r+c,12); }
      n++;
    }
  }
  sendnote(0,60);
}

fun void seek(int t,int q) {
  if (q == 1) { tick => now; }
  else if (q == 2) { bar => now; }
  else if (q == 3) { eightbar => now; }
  t => ticks;
  44100*ticks*15/(bpm*rate) $ int => buffer.pos;
}
 
fun void ticker() {

  while (true) {
    if (buffer.play() == 1) { 

      tick.broadcast();
      ticks % 16 => led_16th;
      if (led_16th > 7) { led_16th + 104 => led_16th; }
      else { led_16th + 96 => led_16th; }
      if (last16th != led_16th) { sendnote(last16th,12); }
      sendnote(led_16th,60);
      led_16th => last16th;

      if (ticks % 16 == 0) {
        bar.broadcast();
        ticks/16 => bars;
        bars % 8 + 80 => led_bars;
        if ( lastbar != led_bars) { sendnote(lastbar,12); }
        sendnote(led_bars,60);
        led_bars => lastbar;
      }

      if (ticks % (16*8) == 0) {
        eightbar.broadcast();
        ticks/128 => eightbars;
        eightbars%8 => int col;
        eightbars/8 => int row;
        16*row+col => led_8bars;
        if (eightbars <= nr_8bars) {
          if (last8 != led_8bars) { sendnote(last8,29); }
          sendnote(led_8bars,60);
          led_8bars => last8;
        }
        else { reset(); }
      }
      ticks + 1 => ticks; 
    }
    tickdur() => now;
  }
}

fun void listen() {

  0 => int pos;
  0 => int lasttrack;
  int q;

  while ( true ) {

    midiin => now;

    while( midiin.recv(inmsg) ) {

      if (inmsg.data1 == 144) { // note

        inmsg.data2%16 => int col;
        inmsg.data2/16 => int row;
        
        if (col < 8) { // grid
          if (inmsg.data3 == 127) { // press
            sendnote(inmsg.data2,56);
            if (row < 5) { 128*(8*row+col) => pos; 3 => q; } // eightbars
            else if (row == 5) { 128*eightbars+16*col => pos; 2 => q; } // bars
            else { 16*bars+8*(row-6)+col => pos; 1 => q; } // 16th
            if (quant == 0) { 0 => q; }
            spork ~ seek(pos,q);
            if (buffer.play() == 0) { // start
              1 => quant;
              1 => buffer.play;
            }
          }
        }

        else if (col == 8) { // A-H
          if (row == 0) { // A
            if (inmsg.data3 == 127) { 0 => quant; } // press
            else if (inmsg.data3 == 0) { 1 => quant; } // release
          }
          else if (row == 1) { // B
            if (inmsg.data3 == 127) { setrate(1.04); } // press
            else if (inmsg.data3 == 0) { setrate(1.0); } // release
          }
          else if (row == 2) { // C
            if (inmsg.data3 == 127) { setrate(0.96); } // press
            else if (inmsg.data3 == 0) { setrate(1.0); } // release
          }
        }
      }

      else if (inmsg.data1 == 176 && inmsg.data3 == 127) { // 1-8 press
        inmsg.data2-104 => int i;
        if (i < nr_files) {
          0 => buffer.play;
          <<< files[i] >>>;
          files[i] => buffer.read;
          (bpm*buffer.samples()/(8*240*44100)) $ int => nr_8bars;
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

spork ~ ticker();
spork ~ listen();

while (true) { minute => now; }
