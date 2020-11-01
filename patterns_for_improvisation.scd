// Boot the server
(
Server.local.options.sampleRate_(44100);
s.boot;
)

/*
Plan:
SynthDefs:
- Bass
- Sin murmur
- Plink

- Reverb
- Compression
*/

s.quit;

(
s.waitForBoot({
	// Busses
	~out = 0;
	~compBus = Bus.audio(s, 2);
	~revBus = Bus.audio(s, 2);

	// Define scales and tonic options
	~tonicOpt = [49, 47, 42, 38];
	~tonic = ~tonicOpt.choose;

	~chooseTonic = {
		~tonic = ~tonicOpt.choose;
	};

	// Modes will have to be redefined each time the tonic changes
	~defineModes = {
		~lydian = (Scale.lydian.degrees+~tonic) ++ (Scale.lydian.degrees+(~tonic+12) ++ (~tonic-12));
		~dorian = (Scale.dorian.degrees+~tonic) ++ (Scale.dorian.degrees+(~tonic+12) ++ (~tonic-12));
		~mixolydian = (Scale.mixolydian.degrees+~tonic) ++ (Scale.mixolydian.degrees+(~tonic+12) ++ (~tonic-12));
	};

	// Mode options can't be defined until the modes themselves are
	~modeOpt = [~lydian, ~dorian, ~mixolydian];

	// Chooses a new tonic, redefines the mode options, and then chooses a new mode and evaluates the bassMode.
	~chooseMode = {
		~chooseTonic.value;
		~tonic.postln;

		~defineModes.value;
		~mode = ~modeOpt.choose;
		~mode.postln;

		~bassMode = (~mode.copyRange(0, 7) - 24);
		~bassMode = (~bassMode ++ [~tonic-24, ~tonic-24, ~tonic+7-24, ~tonic+5-24]);
	};
	~chooseMode.value;

	// Create Synths
	~makeSynths = {
		//SynthDefs
		(
			SynthDef(\reverb, {
				arg in=9, out=0, amp=1,
				mix=0.33, room=0.5, damp=0.5;
				var sig;
				sig = In.ar(in, 2);
				sig = FreeVerb.ar(sig, mix, room, damp);
				sig = sig * amp;
				Out.ar(out, sig);
			}).add;

			SynthDef(\compression, {
				arg in=~compBus, out=0, amp=1,
				thresh=0.2, slopeBelow=1, slopeAbove=0.5, clampTime=0.01, relaxTime=0.01;
				var sig;
				sig = In.ar(in, 2);
				sig = Compander.ar(sig, sig,
					thresh: thresh,
					slopeBelow: slopeBelow,
					slopeAbove: slopeAbove,
					clampTime:  clampTime,
					relaxTime:  relaxTime
				);
				sig = sig * amp;
				Out.ar(out, sig);
			}).add;

			SynthDef(\bpfsin, {
				arg atk=2, sus=0, rel=3, c1='exp', c2='exp',
				freq=500, detune=0.2, pan=0,
				cfmin=500, cfmax=2000, rqmin=0.1, rqmax=0.2, amp=1, out=9;
				var sig, env;
				env = EnvGen.kr(Env([0,1,1,0],[atk,sus,rel],[c1,0,c2]), doneAction:2);
				sig = SinOsc.ar(freq * LFNoise1.kr(0.5,detune).midiratio);
				sig = BPF.ar(
					sig,
					LFNoise1.kr(Rand(0.1, 0.7)).exprange(cfmin, cfmax),
					LFNoise1.kr(Rand(0.1, 0.7)).exprange(rqmin, rqmax)
				);
				sig = Pan2.ar(sig, pan);
				sig = sig * env * amp;
				Out.ar(out, sig);
			}).add;

			SynthDef(\bass, {
				arg atk=2, sus=0, rel=3, c1='exp', c2='exp',
				freq=40, pan=0, amp=0.25, out=0, detune=0.2,
				lpmin=500, lpmax=2000, wmin=0.01, wmax=0.5;
				var sig, env;
				env = EnvGen.kr(Env([0,1,1,0],[atk,sus,rel],[c1,0,c2]), doneAction:2);
				sig = {VarSaw.ar(freq * LFNoise1.kr(0.5,detune).midiratio, Rand(0.001, pi), LFNoise1.kr(Rand(0.1, 0.9)).exprange(wmin, wmax))}!4;
				sig = LPF.ar(
					sig,
					LFNoise1.kr(Rand(0.1, 1.2)).exprange(lpmin, lpmax)
				);
				sig = Mix.ar(sig);
				sig = Pan2.ar(sig, pan);
				amp = amp/4;
				amp = amp/16;
				sig = sig * amp * env;
				Out.ar(out, sig);
			}).add;

			SynthDef(\sawdrone, {
				arg atk=5, sus=inf, rel=4, c1='exp', c2='exp',
				freq=440, pan=0, amp=0, out=0;
				var sig, env;
				env = EnvGen.kr(Env([0,1,1,0], [atk,sus,rel], [c1,c2]), doneAction:2);
				sig = VarSaw.ar(freq, width:SinOsc.kr(0.05, mul:0.25, add:0.5), mul:0.5);
				sig = sig * amp * env;
				sig = Pan2.ar(sig, pan);
				Out.ar(out, sig);
			}).add;

			SynthDef(\plink, {
				arg atk=0.01, rel=3, c1=(-7),
				freq=500, detune=0.2, pan=0, amp=0.2, out=0;
				var sig, env;
				env = EnvGen.kr(
					Env.perc(atk, rel, 1, c1),
					doneAction:0;
				);
				sig = SinOsc.ar(freq * LFNoise1.kr(2, detune).midiratio);
				sig = LPF.ar(sig, freq*1);
				sig = Pan2.ar(sig, rrand(-0.1, 0.1));
				sig = sig * amp * env;
				Out.ar(0, sig);
			}).add;
		)
	};
	~makeSynths.value;

	// Wait for SynthDefs before making patterns
	s.sync;

	// This will run anytime Patterns need to update.
	~makePatterns = {
		~reverb = Pbindef(\reverbP,
			\instrument, \reverb,
			\dur, inf,
			\mix, 0.9/*Pwhite(0.05, 0.9, inf)*/,
			\room, 0.9/*Pwhite(0.001, 0.95, inf)*/,
			\damp, 0.5/*Pwhite(0.05, 0.99, inf)*/,
			\in, ~revBus,
			\out, ~out,
			\amp, 1,
		);

		~compression = Pbindef(\compressionP,
			\instrument, \compression,
			\dur, inf,
			\in, ~compBus,
			\out, ~out,
			\amp, 1,
		);

		~sintext = Pbindef(\sintextP,
			\instrument, \bpfsin,
			\dur, Pwhite(0.25, 2.5, inf),
			\freq, Prand((~mode).midicps, inf),
			\amp, Pexprand(0.2, 0.3),
			\cfmin, Pexprand(100, 500),
			\cfmax, Pexprand(1000, 5000),
			\rqmin, Pexprand(0.005, 0.01),
			\rqmax, Pexprand(0.09, 0.5),
			\pan, Pwhite(-0.75, 0.75),
			\atk, Pwhite(2, 8),
			\sus, Pwhite(4, 10),
			\rel, Pwhite(5, 10),
			\out, ~revBus,
		);

		~bass = Pbindef(\bassP,
			\instrument, \bass,
			\dur, Pwhite(10, 15, inf),
			\freq, Pseq((~bassMode).midicps.scramble, inf),
			\amp, Pexprand(0.1, 0.2),
			\atk, Pwhite(3, 7),
			\sus, 0,
			\rel, Pwhite(5, 10),
			\pan, Pwhite(-0.1, 0.1),
			\amp, 1,
			\c1, 4,
			\c2, -4,
			\out, ~out,
		);

		~drone = Pbindef(\drone,
			\instrument, \sawdrone,
			\dur, inf,
			\freq, (~tonic).midicps,
			\amp, Pwhite(0.05, 0.1),
			\out, ~out,
		);
	};
	~makePatterns.value;

	s.sync;


	~reverb.play;
	~sintext.play;
	~bass.play;
	~drone.play;

	// GUI Button setup
	~function = {
		// chooses a new mode and tonic
		~chooseMode.value;

		// changes values for each instrument
		Pbindef(\sintextP,
			\freq, Prand((~mode).midicps, inf)
		).play;

		Pbindef(\bassP,
			\freq, Prand((~bassMode).midicps, inf)
		).play;

		Pbindef(\reverbP,
			\mix, Pwhite(0.05, 0.9, inf),
			\room, Pwhite(0.001, 0.95, inf),
			\damp, Pwhite(0.05, 0.99, inf)
		).play;

		// This one-time synth plays every time a user presses the "new texture" button
		Synth(\plink, [
			\amp, rrand(0.05, 0.2),
			\freq, ~tonic.midicps
		]);
	};


	// GUI Setup
	~guiWidth = 500;
	~guiHeight = 200;

	Window.closeAll;

	w = Window("Textures for Improv", Rect(
		Window.screenBounds.width/2 - (~guiWidth / 2),
		Window.screenBounds.height/2 - (~guiHeight / 2),
		~guiWidth, ~guiHeight
	))
	.front
	.alwaysOnTop_(true);

	~btnChange = Button(w.view, Rect(45, 45, 170, 100))
	.states_([
		["New Texture", Color.black, Color.gray(0.8)]
	])
	.action_({
		arg obj;
		~function.value;
	});

	~btnIO = Button(w.view, Rect(275, 45, 170, 100))
	.states_([
		["OFF", Color.black, Color.gray(0.8)],
		["ON", Color.white, Color.gray(0.3)],
	])
	.action_({
		arg obj;
	});

});
)

s.meter;

~reverb.play;
~sintext.play;

~chooseMode.value;

~makePatterns.value;
