public class Looper {

  int chan;
  string file;
  SndBuf2 buffer; 
  int bars;
  int multichannel;

  fun void init(int c, int m) {
    c => chan;
    m => multichannel;
    1 => buffer.loop;
    0 => buffer.play;
  }

  fun void connect() {
    if (multichannel) { 
      0 => buffer.channel;
      buffer => dac.chan(chan*2);
      1 => buffer.channel;
      buffer => dac.chan(chan*2+1);
    }
    else { buffer => dac; }
    1 => buffer.play;
  }

  fun void disconnect() {
    0 => buffer.play;
    if (multichannel) { 
      0 => buffer.channel;
      buffer =< dac.chan(chan*2);
      1 => buffer.channel;
      buffer =< dac.chan(chan*2+1);
    }
    else { buffer =< dac; }
  }

  fun void read(string f) {
  <<< f >>>;
    f => file;
    Clock.bar => now;
    disconnect();
    file => buffer.read;
    0 => buffer.phaseOffset;
    0 => buffer.pos;
    connect();
  }

  fun void osc() {
    OscIn oin;
    9669 => oin.port;
    OscMsg msg;
    oin.listenAll();

    while ( true ) {
      oin => now;
      while ( oin.recv(msg) != 0 ) { 
        if (msg.address == "/"+chan+"/read") { spork ~ read(msg.getString(0)); }
        else if (msg.address == "/restart") {
          0 => buffer.phaseOffset;
          0 => buffer.pos;
        }
        else if (msg.address == "/"+chan+"/offset") {
          msg.getInt(0)*Clock.bardur()/8/buffer.length() => buffer.phaseOffset;
        }
        else if (msg.address == "/reset") {
          Clock.bar => now;
          0 => buffer.phaseOffset;
          0 => buffer.pos;
        }
        else if (msg.address == "/rate") { Clock.pulse => now; msg.getFloat(0) => buffer.rate; }
        else if (msg.address == "/"+chan+"/mute") { disconnect(); }
        else if (msg.address == "/"+chan+"/unmute") { connect(); }
      }
    }
  }

}
