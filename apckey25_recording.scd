// Jackson Bierfeldt
// June 22, 2017
// Code for MIDI Controller for APCKEY25

(
// ##########################
// #### INITIALIZE VARIABLES ####
// ##########################

// Variables for Keyboard
var notes, on, off, indexControlKnob, indexControlBus, volumeControlKnob, volumeControlBus;
// Variables for DrumMachine
var drumVolumeControlKnob, drumVolumeControlBus;
// Variables for BufferPlayer
var bufferVolumeControlKnob, bufferVolumeControlBus;
// Variables for Drum Sequencer
var sequencer1, sequencer2, drumSeq, seqArray, buttonRow, buttonArray;
// Variables for Recording
var recButtonArray, recButtonTimeArray, recButtonListener, recButtonArray2, recButtonTimeArray2, recButtonListener2;
// Other Variables
var midiNumber2Synth;
var recordGroup, playGroup;
var recordBufferArray, recordBufferDurationArray, recordSynthArray, recordSynthTimeArray, playSynthArray;
var midiOutController;
var soundDict;

//#########################
//#### INTIIALIZE ALL PARTS ####
//#########################

s = Server.local;
s.options.outDevice_(
	//"Built-in Output"
	//"Multi-Output Device"
	"H6"
	//"Soundflower (2ch)"
);

s.freeAll;
s.options.numOutputBusChannels_(2);
s.options.numInputBusChannels_(2);
s.options.sampleRate_(44100);
s.options.memSize_(2.pow(20));
s.newBusAllocators;
Buffer.freeAll;

s.waitForBoot({

	s.sync;

	~initSynthDefs.value();

	s.sync;

	~initDefaults.value();

	s.sync;

	~initSequencers.value();

	s.sync;

	~initGui.value();

	s.sync;

	~initLoadBuffers.value();

	s.sync;

	~initMidi.value();

	s.sync;

	~initControllerFunctions.value();

	s.sync;

});

























// ###########################
// #### INITIALIZE SYNTH DEFS ####
// ###########################

~initSynthDefs = {

	SynthDef("playBuf", {arg buffer, startPos=0, playRate=1, dur, loop = 0, vol = 1;
		var trigger, env, sound;

		env = EnvGen.kr(Env([0,1,1,0], [0.1, dur-0.2, 0.1]), 1, doneAction:2);

		sound = PlayBuf.ar(2, buffer, BufRateScale.ir(buffer)*playRate, 1, startPos, loop, doneAction: 2);

		// sound = BPF.ar(sound, 440, 0.02, 1/0.02.sqrt);

		sound = Pan2.ar(sound, Line.kr(Rand(-1,1), Rand(-1,1), dur));

		Out.ar(0, sound*env*vol);
	}).add;

	// #################################
	// #### Resonating Clarinet (6 Partials) ####
	// #################################
	SynthDef('rezClarinet6', {arg freq = 200, dur = 0.2, peakVol = 1, vol = 0.5, gate=1;
		var freqs,rings,amps,activator,env,signal;
		freqs = Array.series(6, 1, 2)*freq; // array of 6 odd-numbered partials
		rings = Array.fill(6, dur); // array of values equal to dur
		amps = Array.fill(6, {arg i; (i+1)/6}).reverse; // returns array decreasing from 1 to 0 so that the fundamental freq is lounder

		activator = [BrownNoise.ar(), BrownNoise.ar()] * 0.007; // activator signal for Klank Oscillator Bank, in stereo using multi-channel expansion
		env = EnvGen.kr(Env.adsr(0.1, 0.8, 0.8, 1, peakVol), gate, doneAction:2); // percussive envelope

		signal = DynKlank.ar(`[freqs, amps, rings], activator) * env; //Use DynKlank for dynamic control of osciallator bank

		Out.ar(0, signal * vol)
	}).add;

	// ##################
	// #### FM Clarinet ####
	// ##################

	SynthDef.new(\clarinetfm, {arg freq = 200, dur = 2, in = 0, out = 0, peakVol = 1, vol = 0.5, index = 300, gate=1;
		var  modulator, modulator_env, carrier, carrier_env;

		modulator_env = EnvGen.ar(Env.adsr(0.1, 0.9, 0.8, 1), gate);

		// carrier:modulator 2/3 ratio
		modulator = SinOsc.ar(freq * (3/2), 0) * modulator_env;

		freq = freq+(modulator*index);

		carrier_env = EnvGen.ar(Env.adsr(0.1, 0.8, 0.8, 1, peakVol), gate, doneAction:2);

		carrier = Splay.ar(SinOsc.ar(freq, 0, 0.5) * (carrier_env));

		Out.ar(out, Pan2.ar(carrier * vol))
	}).add;

	// ######################
	// #### HiHatExperiment ####
	// ######################

	SynthDef("HiHatExperiment", {arg glissStart, glissEnd, glissDur, resFreq, resFreqBand, resIndex, resDur, hiHatDur, vol = 1;
		var glissOsc, glissEnv, glissSound;
		var resSound, resBandPass;
		var hiHatEnv, hiHatSound;

		glissOsc = LFPulse.ar(XLine.kr(glissStart, glissEnd, glissDur), 0, 0.1, 0.5);
		glissEnv = EnvGen.kr(Env.perc(0.01, glissDur*2));
		glissSound = glissOsc*glissEnv;

		resSound = SinOsc.ar(XLine.ar(resFreq, resFreq*15/16, resDur)*resIndex + (WhiteNoise.ar(1)));
		resBandPass = Resonz.ar(resSound, resFreqBand, 1, 1);

		hiHatEnv = EnvGen.kr(Env.perc(0.01, hiHatDur), doneAction:2);


		hiHatSound = resBandPass*hiHatEnv + glissSound;
		Out.ar(0, hiHatSound*vol);

	}).add;

	// #################
	// #### Swoooom ####
	// #################

	SynthDef("Swoooom", {arg resFreq, resFreqBand, resIndex, resDur, hiHatDur, vol = 1;
		var resSound, resBandPass;
		var hiHatEnv, hiHatSound;

		resSound = SinOsc.ar(XLine.ar(resFreq, resFreq*15/16, resDur)*resIndex + (WhiteNoise.ar(1)));
		resBandPass = Resonz.ar(resSound, resFreqBand, 1, 1);

		hiHatEnv = EnvGen.kr(Env.perc(0.01, hiHatDur), doneAction:2);


		hiHatSound = resBandPass*hiHatEnv;
		Out.ar(0, hiHatSound*vol);

	}).add;

	// ################
	// #### SpaceTin ####
	// ################

	SynthDef("spaceTin", {arg glissStart, glissEnd, glissDur, spaceTinFreq, spaceTinDur, sineFreq, vol = 1;
		var glissOsc, glissEnv, glissSound;
		var spaceTinSound, spaceTinFilter, spaceTinEnv;
		var shellSound;
		var finalOut;


		//the glissando "crack" sound of the spaceTin - the beater hitting the head
		glissOsc = Impulse.ar(XLine.kr(glissStart, glissEnd, glissDur), 0.0, 0.5, 0.1); //a square wave with a very fast glissando
		glissEnv = EnvGen.kr(Env.perc(0.01, glissDur*2)); //the length of the env is actually twice as long as the duration of the gliss
		glissSound = glissOsc*glissEnv; //the sound is the gliss times the env

		//the resonance of the spaceTins under the drum
		spaceTinSound = WhiteNoise.ar(0.35); //white noise is the sound source
		spaceTinEnv = EnvGen.kr(Env.perc(0.01, spaceTinDur), doneAction:2); //the env is different than the gliss - it also contains the doneAction
		spaceTinSound = spaceTinSound*spaceTinEnv;


		spaceTinFilter = RLPF.ar(spaceTinSound+glissSound, spaceTinFreq); //the filter goes over the sum of the spaceTin and the crack

		//the shell sound
		shellSound = SinOsc.ar(XLine.ar(sineFreq, sineFreq*14/16, spaceTinDur), 0, 0.3);

		shellSound = shellSound*spaceTinEnv; //the shell uses the same env as the spaceTin

		finalOut = LinPan2.ar(shellSound + spaceTinFilter); // the final output is linearly panned across the two channels

		Out.ar(0, finalOut*vol);
	}).add;

	// ################
	// #### NewDrum ####
	// ################

	SynthDef("NewDrum", {arg glissstart, glissend, glissdur, filterfreq, vol = 1;

		var gliss, glissenv, glisssound, metal, metalenv, metalsound, sound, filter;

		//gliss

		gliss=LFPulse.ar(XLine.kr(glissstart, glissend, glissdur), 0, 0.1, 1.0);
		glissenv=EnvGen.kr(Env.perc(0.01, glissdur*rrand(0,5)));
		glisssound=gliss*glissenv;

		//Metal noise
		metal= WhiteNoise.ar(0.1);
		metalenv=EnvGen.kr(Env.perc(0.02, glissdur), doneAction:2);
		metalsound= metal * metalenv;

		sound=glisssound+metalsound;

		//Filter
		filter=Resonz.ar(sound, filterfreq, 0.2, 1.0);

		Out.ar(0, filter.dup*vol);

	}).add;

	// ################
	// #### Table-Shift ####
	// ################

	// Custom sound
	SynthDef("table-shift", {arg glissStart, glissEnd, glissDur, filterFreq, squeakDur, sineFreq, vol = 1;
		var glissOsc, glissEnv, glissSound, squeakSound, squeakEnv, squeakFiltered, shellSound;

		glissOsc = LFPulse.ar(XLine.kr(glissStart, glissEnd, glissDur), 0, 0.1, 0.2);
		glissEnv = EnvGen.kr(Env.perc(0.01, glissDur*4));
		glissSound = glissOsc*glissEnv;

		squeakSound = WhiteNoise.ar(0.2);
		squeakEnv = EnvGen.kr(Env.perc(0.01, squeakDur), doneAction: 2);
		squeakSound = squeakSound*squeakEnv;
		squeakFiltered = RHPF.ar(squeakSound+glissSound, filterFreq);

		shellSound = Saw.ar(XLine.ar(sineFreq, sineFreq*5/16, squeakDur), 0, 0.01);

		Out.ar(0, (squeakFiltered + (shellSound * squeakEnv)) * vol);
	}).add;
};







// ##########################
// #### CREATE DEFAULTS #######
// ##########################

~initDefaults = {

	// Groups for Playing and Recording
	recordGroup = Group.tail(s);
	playGroup = Group.tail(s);

	// 8 Element Array to Store Recorded Buffers
	recordBufferArray = Array.fill(40, {Buffer.alloc(s, 30*s.sampleRate, 2)});

	// 8 Element Array to Store the Durations of Recorded Buffers
	recordBufferDurationArray = Array.fill(40, nil); // duration of recorded buffers

	// 8 Element Array to Store Recording Synths
	recordSynthArray = Array.fill(40, nil);

	// 8 Element Array to Store Time Data for Recording Synths
	recordSynthTimeArray = Array.fill(40, nil); // start-stop times

	// 8 Element Array to Store Synths playing Buffers
	playSynthArray = Array.fill(40, nil);

	// Dictionary of functions to be evaluated
	// each key should be the number of the MIDI button
	buttonArray = Dictionary.new();

	// Set Arrays and Busses
	notes = Array.newClear(128); // Create empty array for tracking on/off notes
	indexControlBus = Bus.control(s, 1); // Control bus for data controlling index modulation
	volumeControlBus = Bus.control(s, 1); // Control bus for data controlling volume
	bufferVolumeControlBus = Bus.control(s, 1); // Control bus for buffer volume
	drumVolumeControlBus = Bus.control(s, 1); // Control bus for drum volume
	volumeControlBus.set(0.5); // Set default volume
	bufferVolumeControlBus.set(0.5);
	drumVolumeControlBus.set(0.5);

};

// ############################
// #### LOAD BUFFERS TO PLAY  ####
// ############################

~initLoadBuffers = {

	~projectPath = PathName(thisProcess.nowExecutingPath).parentPath; // Path to folder containing this file
	~buffersPath = ~projectPath++"buffers/";

	soundDict = Dictionary.new;
	PathName(~buffersPath).entries.do{
		arg subfolder;
		soundDict.add(
			subfolder.folderName.asSymbol ->
			Array.fill(
				subfolder.entries.size,
				{
					arg i;
					Buffer.read(s, subfolder.entries[i].fullPath);
				}
			)
		);
	};

};

// ####################
// ### Drum Sequencers ###
// ####################

~initSequencers = {

	// index for currently selected Task
	~currentTask = 0;

	// Tempo Clock. Default value is 1 (60bpm).
	~tempo = TempoClock.new();

	// Empty List to hold Sequencer Tasks
	// Each Seqeuncer is stored as a multidimensional array with the following items
	// at the given indexes:
	// 0 - The Task Object itself. This can be played and paused and stopped
	// 1 - An array containing the sequence of notes to be played
	// 2 - An array containing the sequence of wait times

	~taskList = List.new();
	~createTask.value([32, 33, 34, 35], [0.25, 0.25, 0.25, 0.25]);

	// Function to create Task
	~createTask = {
		arg noteSeq, durSeq;
		var taskInfoArray, newTask;
		newTask = Task({
			var noteStream, durStream;
			noteStream = Pseq(noteSeq, inf).asStream;
			durStream = Pseq(durSeq, inf).asStream;
			inf.do{
				s.makeBundle(s.latency, {
					// plays corresponding note in buttonArray
					buttonArray[noteStream.next].value;
				});
				durStream.next.wait;
			}
		});
		taskInfoArray = [newTask, noteSeq, durSeq];
		~taskList.add(taskInfoArray);
	};

	// if Sequence or Duration Sequence values have changed, this
	// function repackages them into a new sequence. Pass it an
	// instance of TaskInfoArray.

	~updateTask = {
		arg taskInfoArray;
		var newTask;
		newTask = Task({
			var noteStream, durStream;
			noteStream = Pseq(taskInfoArray[1], inf).asStream;
			durStream = Pseq(taskInfoArray[2], inf).asStream;
			inf.do{
				s.makeBundle(s.latency, {
					// plays corresponding note in buttonArray
					buttonArray[noteStream.next].value;
				});
				durStream.next.wait;
			}
		});
		// If Task is playing, stop, update, and start
		if (taskInfoArray[0].isPlaying == true) {
			taskInfoArray[0].stop;
			"updating...".postln;
			taskInfoArray.put(0, newTask);
			taskInfoArray[0].play(~tempo, quant: 0.25);
		}
		// otherwise, just update
		{
			"updating...".postln;
			taskInfoArray.put(0, newTask);
		};
	};

};

// ########################
// ### SET SOUND FUNCTIONS ##
// ########################

~initControllerFunctions = {

	// ######################################
	// ### SET CONTROL (NON-SOUND) FUNCTIONS ##
	// ######################################

	~nextTask = {
		if((~currentTask+1) >= (~taskList.size) ) {
			~currentTask = 0;
		} {
			~currentTask = ~currentTask+1;
		};
		((~currentTask+1).asSymbol++"/".asSymbol++~taskList.size.asSymbol).postln;
	};

	buttonArray.putPairs([
		// STOP ALL CLIPS - STOP ALL TASKS
		81, {
			/*~taskList.do({
				arg item, i;
				item[0].pause;
			});*/
			recordSynthArray.postln;
		},
		// CLIP STOP - DELETE CURRENT TASK
		82, {
			~currentRow = 32;
		},
		// REC ARM - POST CURRENT TASK
		83, {
			~currentRow = 24;
		},
		84, {
			~currentRow = 16;
		},
		85, {
			~currentRow = 8;
		},
		86, {
			~currentRow = 0;
			buttonArray.postln;
		},
		// SHIFT - CHANGE TO NEXT TASK
		98, {
			~nextTask.value();
		},
		// PLAY/PAUSE
		91, {
			if(~taskList[~currentTask].isNil or: { ~taskList[~currentTask][0].isPlaying.not }) {
				~taskList[~currentTask][0].play(~tempo, quant: 0.25);
			} {
				~taskList[~currentTask][0].stop;
			};
		},
		// REC SEQUENCER 1
		93, {
			// If button is pressed and no array of commands is present or is empty,
			// create a new, empty array, and fill it with commands from the MIDI.
			if(recButtonArray.isNil) {
				"\nSequencer now Recording...".postln;
				recButtonArray = Array();
				recButtonTimeArray = Array();
				~time1 = Main.elapsedTime;
				recButtonListener = MIDIFunc.noteOn({arg ...args;
					if(args[1] <= 39) {
						recButtonTimeArray = recButtonTimeArray.add((Main.elapsedTime - ~time1).round(0.125));
						recButtonArray = recButtonArray.add(args[1]);
						~time1 = Main.elapsedTime;
						recButtonTimeArray.postln;
					} {};
				}, chan: 0);
			} {
				if(recButtonArray == []) {
					"empty...".postln;
					recButtonListener.free;
					recButtonArray = nil;
				} {
					// If button is pressed and an array of commands IS present,
					// free the MIDI listener, set the drumSeq for Sequencer 1 to equal the
					// newly recorded commands, and empty the recording array
					recButtonListener.free;
					recButtonTimeArray = recButtonTimeArray.add((Main.elapsedTime - ~time1).round(0.125));
					recButtonTimeArray.removeAt(0); // remove first time, which is the time since pressing REC and pressing the first note
					"\nNew Recorded Sequence:".postln; recButtonArray.postln; ~setWindowText.value(recButtonArray);
					"New Recorded Sequence Time:".postln; recButtonTimeArray.postln;
					~createTask.value(recButtonArray, recButtonTimeArray);
					~nextTask.value;
					~taskList[~currentTask][0].play(~tempo, quant: 0.25);
					recButtonArray = nil;
				}
			};
		}
	]);


	buttonArray.keysDo({arg key;
		midiOutController.noteOn(0, key);
	});

	40.do({arg i;
		buttonArray.put(i, {Synth("playBuf", [\buffer, recordBufferArray[i], \dur, recordBufferDurationArray[i], \playRate, 1, \vol, bufferVolumeControlBus.asMap], playGroup)});
	});

};

~initMidi = {

	// ######################################
	// ### CONNECT TO APC25 MIDI CONTROLLER ###
	// #####################################

	MIDIClient.init;
	MIDIIn.connectAll;
	midiOutController = MIDIOut(0); //sets midiOut for LED control

	~currentRow = 8;

	// Set Responders for all chan 0 buttons (0–92)
	// on press, runs the function in the buttonArray
	// dictionary
	MIDIFunc.noteOn({
		arg ...msgs;
		buttonArray[msgs[1]].value;

		// Refresh the GUI any time a Button is Pressed
		~gui_RefreshCurrentTask.value();
	}, chan: 0);

	// ############################
	// ### MIDI SETUP FOR KEYBOARD ###
	// ############################

	// NoteOn MIDI Responder
	on = MIDIFunc.noteOn({arg ...args;
		var event, newInstance;
		event = args[1];
		newInstance = Synth.new(\clarinetfm,[\freq, args[1].midicps, \peakVol, (args[0]/127), \vol, volumeControlBus.asMap, \dur, 2, \index, indexControlBus.asMap]);
		notes.put(event, newInstance);
	}, chan: 1); // match any noteOn

	// NoteOff MIDI Responder
	off = MIDIFunc.noteOff({arg ...args;
		notes[args[1]].set(\gate,  0);
	}, chan: 1); // match any noteOff

	// IndexControlKnob MIDI Responder
	indexControlKnob = MIDIFunc.cc({arg ...args;
		var adjustedInput;
		adjustedInput = args[0].linlin(0,127,0,500); // index ranges from 0–500
		indexControlBus.set(adjustedInput);
	}, 48, chan: 0);

	// VolumeControlKnob MIDI Responder
	volumeControlKnob = MIDIFunc.cc({arg ...args;
		var adjustedInput;
		adjustedInput = args[0].linlin(0,127,0.0,1.0); // volume ranges from 0.0–1.0
		volumeControlBus.set(adjustedInput);
	}, 52, chan: 0);

	// drumVolumeControlKnob MIDI Responder
	drumVolumeControlKnob = MIDIFunc.cc({arg ...args;
		var adjustedInput;
		adjustedInput = args[0].linlin(0,127,0.0,1.0); // volume ranges from 0.0–1.0
		drumVolumeControlBus.set(adjustedInput);
	}, 49, chan: 0);

	// BufferVolumeControlKnob MIDI Responder
	bufferVolumeControlKnob = MIDIFunc.cc({arg ...args;
		var adjustedInput;
		adjustedInput = args[0].linlin(0,127,0.0,1.0); // volume ranges from 0.0–1.0
		bufferVolumeControlBus.set(adjustedInput);
	}, 50, chan: 0);

	// TempoControlKnob
	MIDIFunc.cc({arg val, num;
		~tempo.tempo = val.linlin(0, 127, 0.25, 2).round(0.25).postln;
	}, 55, chan: 0);

	// ######################################
	// ### Responders for BufferRecorders ###
	// #####################################

	~setRecorders = {
		8.do({
			arg i;

			//BufferRecord On
			MIDIFunc.noteOn({
				arg ...msgs;
				var newSynth;
				newSynth = Synth("recordSynth", [\inBus, [0,1], \buffer,recordBufferArray[~currentRow + i], \gate, 1], recordGroup);
				recordSynthTimeArray.put(~currentRow + i, Main.elapsedTime); // record synth start time
				recordSynthArray.put(~currentRow + i, newSynth);
				recordSynthArray.postln;
			}, i+64, chan: 0);

			//BufferRecord Off
			MIDIFunc.noteOff({
				arg ...msgs;
				recordSynthArray[~currentRow + i].set(\gate,  0);
				recordSynthArray[~currentRow + i] = nil;
				recordBufferDurationArray.put(~currentRow + i, Main.elapsedTime - recordSynthTimeArray[~currentRow + i]).postln;
				midiOutController.noteOn(0, ~currentRow + i);
			}, i+64, chan: 0);
		});

	};

	~setRecorders.value();

};

~initGui = {
	var window, layout;
	var currentTaskInfo, currentTaskNumber, currentTaskPlaying, currentTaskDur, currentTaskSequence;
	var editCurrentTaskButton;

	currentTaskNumber = StaticText(window).background_(Color.white).align_(\center).font_(Font("Helvetica", 36));
	currentTaskPlaying = StaticText(window).background_(Color.red).string_("OFF").align_(\center).font_(Font("Helvetica", 36));

	currentTaskSequence = StaticText(window).background_(Color.white).align_(\center);
	currentTaskDur = StaticText(window).background_(Color.white).align_(\center);

	// create button which opens task editing window
	editCurrentTaskButton = Button(window).string_("Edit Task").action_({arg i;
		var editWindow, editLayout;
		var taskNumberLabel, sequenceText, durText, saveButton;
		var taskIndex, newSeq, newDur;

		taskIndex = ~currentTask;

		taskNumberLabel = StaticText(editWindow).string_(taskIndex).background_(Color.white).align_(\center).font_(Font("Helvetica", 36));

		// Text Fields for editing Sequence and Duration values
		// After editing, string must be in the form of an array
		sequenceText = TextField(editWindow).value_(~taskList[taskIndex][1]).action_({
			arg field;
			// .interpret changes the string into an array
			newSeq = field.value.interpret;
		});
		durText = TextField(editWindow).value_(~taskList[taskIndex][2]).action_({
			arg field;
			// .interpret changes the string into an array
			newDur = field.value.interpret;
		});

		saveButton = Button(editWindow).string_("Save/Update Task").action_({
			sequenceText.doAction();
			durText.doAction();
			"saving...".postln;

			~taskList[taskIndex].put(1, newSeq);
			~taskList[taskIndex].put(2, newDur);

			~updateTask.value(~taskList[taskIndex]);

			~gui_RefreshCurrentTask.value();

		});

		editLayout = GridLayout.rows(
			[[taskNumberLabel, columns: 2]],
			[sequenceText,durText],
			[saveButton]
		).setMinRowHeight(1, 200);
		editWindow = Window.new("Task Edit Info Pane", Rect(128, 64, 340, 360)).layout_(editLayout).front;
	});

	currentTaskInfo = GridLayout.rows([currentTaskNumber, currentTaskPlaying], [currentTaskSequence, currentTaskDur], [editCurrentTaskButton]);

	// default with vertical layout
	layout = GridLayout.rows([]);
	window = Window.new("Current Task Info Pane").layout_(
		layout
	).toFrontAction_({~gui_RefreshCurrentTask.value();}).front;

	layout.add(currentTaskInfo, 0, 0);

	// Public Function to be called when refreshing GUI info
	// for current Task info pane
	~gui_RefreshCurrentTask = {
		{
			// set Current Task Number
			currentTaskNumber.string = (~currentTask+1);

			if(~taskList.isEmpty) {
				nil
			} {
				// set Play/Pause
				case
				{~taskList[~currentTask][0].isPlaying == true} {
					currentTaskPlaying.background_(Color.green).string_("ON");
				}
				{~taskList[~currentTask][0].isPlaying == false} {
					currentTaskPlaying.background_(Color.red).string_("OFF");
				};

				// set Current Task Sequence
				currentTaskSequence.string = ~taskList[~currentTask][1];

				// set Current Task Duration
				currentTaskDur.string = ~taskList[~currentTask][2];
			}
		}.defer;
	};

	// close window with Cmd+.
	CmdPeriod.doOnce({window.close});

	// refresh window on start-up
	~gui_RefreshCurrentTask.value();

};

)

~currentRow;

MIDIFunc.noteOn({arg ...msgs;
	msgs.postln;
});