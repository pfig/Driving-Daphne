// ==========================================================================================
//
//
//                                      Driving Daphne
//
//
//                                     Pedro Figueiredo
//                                      @anythingdies
//                                       noise=noise
//                                        Jan 2012
// ==========================================================================================

Server.default = s = Server.internal;
s.boot.makeGui;
~nano = NanoKONTROL();

// A SynthDef to record
SynthDef ( \recorder, { | bufnum |
  DiskOut.ar( bufnum, In.ar( 0, 2 ) );
}).add;

(
var woolPath = "/Users/pfig/Music/OraMIX/nnnnn/Wool.wav";
var woolBuffer;

// The pieces
var intro, foundation, glitch, mainScene;

var engine;

{

// ==========
// SynthDefs
// ==========

// A looper for in-memory stereo samples
SynthDef( \loopSample2, { | buf, out = 0, amp = 1, rate = 1 |
  var sound;
  
  sound = PlayBuf.ar( 2, buf, BufRateScale.ir( buf ) * rate, loop: 1 );
  
  Out.ar( out, sound * amp );
}).add;

// A glitcher
SynthDef( \glitch, { | buf, out = 0, freq = 440, amp = 1, dur = 0.25 |
  var sound, env;
  
  env = Env( [ 0, 1, 0 ], [ 0.5 * dur, 0.5 * dur ] );
  sound = LFSaw.ar( freq, mul: amp );
  sound = sound * EnvGen.kr( env, doneAction: 2 );
  
  Out.ar( out, sound );
}).add;

// A grain to play the foundation
SynthDef( \foundation, { | buf, out = 0, rate = 1, amp = 0.8, offset = 0, dur = 0.1 |
  var sound, env;
  
  // a crude ADSR envelope
  env = Env( [ 0, 1, 0.5, 0.5, 0 ], [ 0.2 * dur, 0.25 * dur, 0.3 * dur, 0.25 * dur ] );
  
  sound = PlayBuf.ar( 2, buf, BufRateScale.ir( buf ) * rate, startPos: offset, loop: 1 );
  sound = sound * EnvGen.kr( env, doneAction: 2 );
  
  Out.ar( out, sound * amp );
}).add;

// The main grain SynthDef
SynthDef( \grain, { | buf, out = 0, rate = 1, amp = 1, dur = 0.03, offset = 0 |
  var sound, env;
  
  env = Env( [ 0, 1, 0.4, 0 ], [ 0.2 * dur, 0.5 * dur, 0.3 * dur ] );

  sound = PlayBuf.ar( 2, buf, BufRateScale.ir( buf ) * rate, startPos: offset, loop: 1 );
  sound = sound * EnvGen.kr( env, doneAction: 2 );
  
  Out.ar( out, sound * amp );
}).add;

s.sync;

// =================================
// Create the grains and the engine
// =================================
engine = { | path, pos, rate, dur |
  var position;  // position where to get the grain from
  var duration;  // grain duration
  var paths;     // the list of files to use as grain sources
  var silo;      // an array to store the grains
  //  ~grainAmp;  // the amplitude for a grain, 1/n when it starts
  //  ~grainRate; // the rate for a grain

  paths = PathName( path ).entries;
  
  silo = Array.newClear( paths.size );

  position = Array.newClear( paths.size );
  position.fill( 0 );

  ~grainAmp = Array.newClear( paths.size );
  ~grainAmp.fill( 1 / paths.size );
  
  ~grainRate = Array.newClear( paths.size );
  ~grainRate.fill( 1 );
  
  // Set up MIDI
  paths.size.do { | idx |
    ~nano.sliders[0][idx].action_( { | slider |
      ~grainAmp[idx] = ControlSpec( 0, 1, step: 0.01 ).map( slider.value ).postln;
    }
  )};


  paths.size.do { | idx |
    ~nano.knobs[0][idx].action_( { | knob |
      ~grainRate[idx] = ControlSpec( -1, 1, step: 0.01 ).map( knob.value ).postln;
    }
  )};

  silo.size.do { | idx |
    var buffer = Buffer.read( s, paths[idx].fullPath );
    s.sync;
    
    silo[idx] = { loop {
      if ( position[idx] > buffer.numFrames ) { position[idx] = 0 } { position[idx] = position[idx] + rrand( 4410, 12000 ) };
      Synth( \grain, [
        \buf, buffer,
        \rate, ~grainRate[idx],
        \amp, ~grainAmp[idx],
        \offset, position[idx]
      ], s, \addToHead );
      0.06.wait;
    }}.fork;
  };
};

// ================
// Start the riot!
// ================

// Load the file used for intro and foundation
woolBuffer = Buffer.read( s, woolPath );
s.sync;

// Start recording
~outBuf = Buffer.alloc( s, 65536, 2 );
~outBuf.write(
  "/Users/pfig/Music/OraMIX/DrivingDaphne.aiff".standardizePath,
  "aiff", "int16",
  0, 0, true
);
~recorder = Synth.tail( nil, \recorder, [ \bufnum, ~outBuf ] );

// ===============
// Play the intro
// ===============
intro = Synth( \loopSample2, [ \buf, woolBuffer ] );
{intro.free}.defer( 28 ); // we only want the first 28 seconds

// =====================
// Start the foundation
// =====================
foundation = Task {{
  var pos = 0;
   
  { loop {
    if ( pos >= woolBuffer.numFrames ) { pos = 0 } { pos = pos + 4410 };
    Synth(
      \foundation,
      [ \buf, woolBuffer, \rate, -0.5.rand, \dur, 0.9.rand, \offset, pos ]
    );
    0.1.rand.wait;
  }};
}.play};
SystemClock.sched( 25.0, { foundation.start; nil; } ); // start 25 seconds after the intro

// ===================
// Start the glitcher
// ===================

glitch = Task {{
  { loop {
    if ( 0.15.coin )
      { Synth( \glitch, [ \freq, rrand( 20, 100 ), \amp, 0.175, \dur, rrand( 0.01, 0.15 ) ] ) }
      { nil };
    15.0.rand.wait;
  }};
}.play};
SystemClock.sched( 55.0, { glitch.start; nil; } ); // start glitching 30 seconds into the foundation

// =====================
// Start the main piece
// =====================

mainScene = Task {{
  engine.value( "/Users/pfig/Music/OraMIX/nnnnn/wheat" );
}.play};
SystemClock.sched( 90.0, { mainScene.start; nil; } ); // start the main grains 35 seconds after

}.fork;

)

// =============
// Ending
// =============
{
  Pan2.ar( Gendy2.ar(
    adparam: LFSaw.kr( 1 ),
    ddparam: LFNoise2.kr( 2 ),
    mul: MouseY.kr( 1, 0 )
  ))
}.play;

// ===============
// Stop recording
// ===============
~recorder.free;
~outBuf.close;
~outBuf.free;

