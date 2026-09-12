package states.editors;

import flixel.input.keyboard.FlxKey;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import flixel.ui.FlxButton;
import openfl.media.Sound;
import haxe.Json;

import backend.ui.PsychUIInputText;
import backend.ui.PsychUIDropDownMenu;
import objects.Character.CharacterFile;
import states.editors.content.MetaNote;
import states.editors.content.*; // trae EventMetaNote

/**
 * Editor de eventos con 3 carriles independientes, cuadros tipo Chart Editor,
 * botones táctiles, voces sincronizadas y preview de sonidos KB.
 * NO tiene barra de flechas / grid de notas: solo trabaja con PlayState.SONG.events.
 */
class KBEventEditorState extends MusicBeatState
{
	static inline final LANE_COUNT:Int = 3;
	static final LANE_X:Array<Float> = [200, 500, 800];
	static final LANE_NAMES:Array<String> = ['Carril A', 'Carril B', 'Carril C'];
	static inline final PIXELS_PER_MS:Float = 0.25;
	static inline final BOX_SIZE:Float = 40;
	static inline final SOUND_SKIN:String = 'kade'; // mismo default que KB_DodgeFixx.lua

	// Botones rápidos de eventos KB_ (se colocan en el carril activo, en el tiempo actual)
	static final KB_BUTTONS:Array<Array<String>> = [
		['KB_Alert (1)', 'KB_Alert', '1', ''],
		['KB_Alert (2)', 'KB_Alert', '2', ''],
		['KB_Alert (3)', 'KB_Alert', '3', ''],
		['KB_Alert (4)', 'KB_Alert', '4', ''],
		['Prepare', 'KB_AttackPrepare', '1', ''],
		['Fire', 'KB_AttackFire', '1', ''],
		['Careless', 'Careless_Alert', '', ''],
		['EnableDodge', 'EnableDodge', '', ''],
		['DisableDodge', 'DisableDodge', '', ''],
	];

	static final KB_HOTKEYS:Map<FlxKey, Int> = [
		ONE => 0, TWO => 1, THREE => 2, FOUR => 3,
		P => 4, F => 5, C => 6, N => 7, M => 8,
	];

	static final ALERT_SOUNDS:Array<String> = ['alert', 'alertDouble', 'alertTriple', 'alertQuadruple', 'alertQuintuple', 'alertSixtuple'];
	static final ATTACK_SOUNDS:Array<String> = ['attack', 'attack-double', 'attack-triple', 'attack-quadruple', 'attack-quintuple', 'attack-sixtuple'];

	var laneEvents:Array<Array<EventMetaNote>> = [[], [], []];
	var laneGroup:FlxTypedGroup<EventMetaNote> = new FlxTypedGroup<EventMetaNote>();
	var laneLabels:Array<FlxText> = [];
	var boxGroup:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

	// Rects de los cuadros visibles este frame, para detectar el toque
	var visibleBoxes:Array<{x:Float, y:Float, w:Float, h:Float, lane:Int, time:Float}> = [];

	var activeLane:Int = 0;
	var scrollTime:Float = 0;
	var lastCheckedTime:Float = 0;

	var playhead:FlxSprite;
	var infoText:FlxText;
	var headerText:FlxText;
	var selectedEvent:EventMetaNote = null;

	// Audio
	var vocals:FlxSound = new FlxSound();
	var opponentVocals:FlxSound = new FlxSound();

	// UI táctil
	var eventButtons:Array<FlxButton> = [];
	var eventDropDown:PsychUIDropDownMenu;

	var value1Input:PsychUIInputText;
	var value2Input:PsychUIInputText;

	override function create()
	{
		Conductor.songPosition = 0;
		persistentUpdate = persistentDraw = false;

		FlxG.sound.list.add(vocals);
		FlxG.sound.list.add(opponentVocals);
		vocals.autoDestroy = opponentVocals.autoDestroy = false;

		loadAudio();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(18, 18, 24));
		bg.scrollFactor.set();
		add(bg);

		for (i in 0...LANE_COUNT)
		{
			var line:FlxSprite = new FlxSprite(LANE_X[i] - 1, 0).makeGraphic(2, FlxG.height, FlxColor.fromRGB(80, 80, 90));
			line.scrollFactor.set();
			add(line);
		}

		add(boxGroup);
		add(laneGroup);

		playhead = new FlxSprite(0, 0).makeGraphic(FlxG.width, 2, FlxColor.RED);
		playhead.scrollFactor.set();
		add(playhead);

		headerText = new FlxText(10, 4, FlxG.width - 20, '', 15);
		headerText.color = FlxColor.YELLOW;
		headerText.scrollFactor.set();
		add(headerText);

		buildLaneButtons();
		buildEventSelector();
		buildEventButtons();
		buildBottomBar();

		infoText = new FlxText(10, FlxG.height - 168, FlxG.width - 20, '', 14);
		infoText.scrollFactor.set();
		add(infoText);

		loadExistingEvents();

		addTouchPad('LEFT_FULL', 'CHART_EDITOR');

		super.create();
	}

	// ---------------- Audio ----------------

	function loadAudio()
	{
		try
		{
			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		catch (e:Dynamic)
		{
			FlxG.log.error('Error cargando instrumental: $e');
		}

		// Soporta canciones con Voices.ogg único O Voices-Player/Voices-Opponent separados,
		// exactamente igual que el Chart Editor (Paths.voices ya resuelve cuál usar).
		if (PlayState.SONG.needsVoices)
		{
			try
			{
				var charP1:CharacterFile = loadCharacterFile(PlayState.SONG.player1);
				var charP2:CharacterFile = loadCharacterFile(PlayState.SONG.player2);
				var vocalsP1:String = (charP1 != null && charP1.vocals_file != null && charP1.vocals_file.length > 0) ? charP1.vocals_file : 'Player';
				var vocalsP2:String = (charP2 != null && charP2.vocals_file != null && charP2.vocals_file.length > 0) ? charP2.vocals_file : 'Opponent';

				var playerVocals:Sound = Paths.voices(PlayState.SONG.song, vocalsP1);
				vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(PlayState.SONG.song));
				vocals.volume = 1;
				vocals.play();
				vocals.pause();
				vocals.time = 0;

				var oppVocals:Sound = Paths.voices(PlayState.SONG.song, vocalsP2);
				if (oppVocals != null && oppVocals.length > 0)
				{
					opponentVocals.loadEmbedded(oppVocals);
					opponentVocals.volume = 1;
					opponentVocals.play();
					opponentVocals.pause();
					opponentVocals.time = 0;
				}
			}
			catch (e:Dynamic)
			{
				FlxG.log.error('Error cargando voces: $e');
			}
		}
	}

	function loadCharacterFile(char:String):CharacterFile
	{
		if (char != null)
		{
			try
			{
				var path:String = Paths.getPath('characters/' + char + '.json', TEXT);
				#if MODS_ALLOWED
				var unparsedJson = File.getContent(path);
				#else
				var unparsedJson = Assets.getText(path);
				#end
				return cast Json.parse(unparsedJson);
			}
			catch (e:Dynamic) {}
		}
		return null;
	}

	function togglePlay()
	{
		if (FlxG.sound.music.playing)
		{
			FlxG.sound.music.pause();
			vocals.pause();
			opponentVocals.pause();
		}
		else
		{
			FlxG.sound.music.play();
			if (vocals.length > 0) { vocals.time = FlxG.sound.music.time; vocals.play(); }
			if (opponentVocals.length > 0) { opponentVocals.time = FlxG.sound.music.time; opponentVocals.play(); }
		}
	}

	function seek(deltaMs:Float)
	{
		var wasPlaying:Bool = FlxG.sound.music.playing;
		if (wasPlaying) { FlxG.sound.music.pause(); vocals.pause(); opponentVocals.pause(); }

		Conductor.songPosition = Math.max(0, Conductor.songPosition + deltaMs);
		FlxG.sound.music.time = Conductor.songPosition;
		if (vocals.length > 0) vocals.time = Conductor.songPosition;
		if (opponentVocals.length > 0) opponentVocals.time = Conductor.songPosition;

		if (wasPlaying) togglePlay();
	}

	// ---------------- UI táctil ----------------

	function buildLaneButtons()
	{
		for (i in 0...LANE_COUNT)
		{
			var btn:FlxButton = new FlxButton(LANE_X[i] - 55, 24, LANE_NAMES[i], function() activeLane = i);
			btn.scrollFactor.set();
			add(btn);

			var label:FlxText = new FlxText(LANE_X[i] - 55, 50, 110, '', 12);
			label.alignment = CENTER;
			label.scrollFactor.set();
			add(label);
			laneLabels.push(label);
		}
	}

	function buildEventSelector()
	{
		// Lista de eventos disponibles para colocar tocando un cuadro: primero los KB_, luego los normales del engine
		var kbNames:Array<String> = [for (b in KB_BUTTONS) b[1]];
		var otherNames:Array<String> = [for (e in ChartingState.defaultEvents) e[0]];
		var allNames:Array<String> = kbNames.concat(otherNames.filter(n -> kbNames.indexOf(n) < 0));

		var label:FlxText = new FlxText(10, FlxG.height - 268, 100, 'Evento a colocar:', 12);
		label.scrollFactor.set();
		add(label);

		eventDropDown = new PsychUIDropDownMenu(140, FlxG.height - 272, allNames, function(id:Int, name:String) {});
		eventDropDown.scrollFactor.set();
		add(eventDropDown);

		var v1Label:FlxText = new FlxText(360, FlxG.height - 268, 55, 'Value 1:', 12);
		v1Label.scrollFactor.set();
		add(v1Label);

		value1Input = new PsychUIInputText(420, FlxG.height - 272, 80, '', 12);
		value1Input.scrollFactor.set();
		value1Input.onChange = function(_, newText:String)
		{
			if (selectedEvent != null) selectedEvent.events[0][1] = newText;
		};
		add(value1Input);

		var v2Label:FlxText = new FlxText(510, FlxG.height - 268, 55, 'Value 2:', 12);
		v2Label.scrollFactor.set();
		add(v2Label);

		value2Input = new PsychUIInputText(570, FlxG.height - 272, 130, '', 12);
		value2Input.scrollFactor.set();
		value2Input.onChange = function(_, newText:String)
		{
			if (selectedEvent != null) selectedEvent.events[0][2] = newText;
		};
		add(value2Input);
	}

	function buildEventButtons()
	{
		// Atajos rápidos de eventos KB_ (además de los cuadros, para no tener que abrir el dropdown cada vez)
		var startX:Float = 10;
		var y:Float = FlxG.height - 230;
		var btnWidth:Float = 100;
		var perRow:Int = 6;

		for (i in 0...KB_BUTTONS.length)
		{
			var data = KB_BUTTONS[i];
			var col:Int = i % perRow;
			var row:Int = Std.int(i / perRow);
			var btn:FlxButton = new FlxButton(startX + col * (btnWidth + 6), y + row * 36, data[0], function()
			{
				addEvent(data[1], data[2], data[3], activeLane);
			});
			btn.setGraphicSize(Std.int(btnWidth), 32);
			btn.updateHitbox();
			btn.scrollFactor.set();
			add(btn);
			eventButtons.push(btn);
		}
	}

	function buildBottomBar()
	{
		var y:Float = FlxG.height - 40;

		addSmallButton(10, y, 'Retroceder', function() seek(-5000));
		addSmallButton(120, y, 'Play/Pausa', togglePlay);
		addSmallButton(230, y, 'Guardar', saveEvents);
		addSmallButton(330, y, 'Borrar sel.', deleteSelected);
		addSmallButton(430, y, 'Borrar KB', deleteAllKBEvents);
		addSmallButton(540, y, 'Borrar TODO', deleteAllEvents);
		addSmallButton(FlxG.width - 90, y, 'Salir', closeEditor);
	}

	function addSmallButton(x:Float, y:Float, label:String, cb:Void->Void)
	{
		var btn:FlxButton = new FlxButton(x, y, label, cb);
		btn.scrollFactor.set();
		add(btn);
	}

	// ---------------- Carga / eventos ----------------

	function loadExistingEvents()
	{
		for (lane in laneEvents) for (ev in lane) if (ev != null) ev.destroy();
		laneEvents = [[], [], []];
		laneGroup.clear();

		var i:Int = 0;
		if (PlayState.SONG.events != null)
		{
			for (eventGroup in PlayState.SONG.events)
			{
				if (eventGroup == null) continue;
				placeLoadedEvent(eventGroup, i % LANE_COUNT); // reparto visual, no afecta el guardado
				i++;
			}
		}
	}

	function placeLoadedEvent(songData:Dynamic, lane:Int)
	{
		var ev:EventMetaNote = new EventMetaNote(songData[0], songData);
		finishEventSetup(ev, lane);
		laneEvents[lane].push(ev);
	}

	function finishEventSetup(ev:EventMetaNote, lane:Int)
	{
		ev.x = LANE_X[lane] - ev.width / 2;
		ev.eventText.x = ev.x + ev.width + 10;
		ev.scrollFactor.set();
		ev.eventText.scrollFactor.set();
		laneGroup.add(ev);
	}

	function addEvent(name:String, value1:String, value2:String, lane:Int, ?atTime:Float)
	{
		var time:Float = atTime != null ? atTime : Conductor.songPosition;
		var songData:Array<Dynamic> = [time, [[name, value1, value2]]];
		var ev:EventMetaNote = new EventMetaNote(time, songData);
		finishEventSetup(ev, lane);
		laneEvents[lane].push(ev);
		selectEvent(ev);
	}

	function selectEvent(ev:EventMetaNote)
	{
		selectedEvent = ev;
		if (ev != null)
		{
			var data = ev.events[0];
			value1Input.text = data[1] != null ? Std.string(data[1]) : '';
			value2Input.text = data[2] != null ? Std.string(data[2]) : '';
			var idx:Int = eventDropDown.list.indexOf(data[0]);
			if (idx >= 0) eventDropDown.selectedIndex = idx;
		}
	}

	function deleteSelected()
	{
		if (selectedEvent == null) return;
		for (laneIndex in 0...LANE_COUNT)
		{
			if (laneEvents[laneIndex].remove(selectedEvent))
			{
				laneGroup.remove(selectedEvent, true);
				selectedEvent.destroy();
				selectEvent(null);
				return;
			}
		}
	}

	function deleteAllEvents()
	{
		for (lane in laneEvents) for (ev in lane) { laneGroup.remove(ev, true); ev.destroy(); }
		laneEvents = [[], [], []];
		selectEvent(null);
	}

	function deleteAllKBEvents()
	{
		for (laneIndex in 0...LANE_COUNT)
		{
			var kept:Array<EventMetaNote> = [];
			for (ev in laneEvents[laneIndex])
			{
				if (isKBEvent(ev.events[0][0]))
				{
					laneGroup.remove(ev, true);
					if (selectedEvent == ev) selectEvent(null);
					ev.destroy();
				}
				else kept.push(ev);
			}
			laneEvents[laneIndex] = kept;
		}
	}

	function isKBEvent(name:String):Bool
	{
		return name != null && (name.startsWith('KB_') || name == 'Careless_Alert'
			|| name == 'EnableDodge' || name == 'DisableDodge'
			|| name == 'newDodgeDuration' || name == 'newDodgeCooldown' || name == 'CessationTroll');
	}

	// ---------------- Loop principal ----------------

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		handleTransportKeys(elapsed);
		handleHotkeys();
		rebuildGridBoxes();
		handleTap();
		repositionEvents();
		updatePlayhead();
		checkAlertPreview();
		updateTexts();

		if (FlxG.keys.justPressed.ESCAPE) closeEditor();
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveEvents();
	}

	function handleTransportKeys(elapsed:Float)
	{
		if (touchPad.buttonX.justPressed || FlxG.keys.justPressed.SPACE)
			togglePlay();

		if (FlxG.sound.music.playing)
		{
			Conductor.songPosition = FlxG.sound.music.time;
		}
		else if (touchPad.buttonUp.pressed || FlxG.keys.pressed.W
			|| touchPad.buttonDown.pressed || FlxG.keys.pressed.S
			|| FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.LEFT)
		{
			var speedMult:Float = (touchPad.buttonY.pressed || FlxG.keys.pressed.SHIFT) ? 4 : 1;
			var timeAdd:Float = 700 * speedMult * elapsed;

			if (touchPad.buttonUp.pressed || FlxG.keys.pressed.W || FlxG.keys.pressed.LEFT)
				Conductor.songPosition -= timeAdd;
			else if (touchPad.buttonDown.pressed || FlxG.keys.pressed.S || FlxG.keys.pressed.RIGHT)
				Conductor.songPosition += timeAdd;

			Conductor.songPosition = Math.max(0, Conductor.songPosition);
			FlxG.sound.music.time = Conductor.songPosition;
			if (vocals.length > 0) vocals.time = Conductor.songPosition;
			if (opponentVocals.length > 0) opponentVocals.time = Conductor.songPosition;
		}

		scrollTime = Conductor.songPosition - (FlxG.height / 2) / PIXELS_PER_MS;
	}

	function handleHotkeys()
	{
		for (key => index in KB_HOTKEYS)
		{
			if (FlxG.keys.checkStatus(key, JUST_PRESSED))
			{
				var data = KB_BUTTONS[index];
				addEvent(data[1], data[2], data[3], activeLane);
				break;
			}
		}
	}

	// ---------------- Cuadros tipo Chart Editor ----------------

	function rebuildGridBoxes()
	{
		boxGroup.clear();
		visibleBoxes = [];

		var step:Float = Conductor.stepCrochet;
		if (step == null || step <= 0) step = 200;

		var firstStep:Int = Math.floor(scrollTime / step) - 1;
		var lastStep:Int = Math.ceil((scrollTime + FlxG.height / PIXELS_PER_MS) / step) + 1;

		for (lane in 0...LANE_COUNT)
		{
			for (s in firstStep...lastStep)
			{
				var time:Float = s * step;
				var y:Float = (time - scrollTime) * PIXELS_PER_MS - BOX_SIZE / 2;
				var x:Float = LANE_X[lane] - BOX_SIZE / 2;

				var box:FlxSprite = new FlxSprite(x, y).makeGraphic(Std.int(BOX_SIZE), Std.int(BOX_SIZE), FlxColor.TRANSPARENT);
				box.makeGraphic(Std.int(BOX_SIZE), Std.int(BOX_SIZE), 0x00000000);
				FlxSpriteUtil.drawRect(box, 0, 0, BOX_SIZE, BOX_SIZE, FlxColor.TRANSPARENT, {thickness: 1, color: FlxColor.fromRGB(60, 60, 70)});
				box.scrollFactor.set();
				boxGroup.add(box);

				visibleBoxes.push({x: x, y: y, w: BOX_SIZE, h: BOX_SIZE, lane: lane, time: time});
			}
		}
	}

	function handleTap()
	{
		if (!FlxG.mouse.justPressed || PsychUIInputText.focusOn != null) return;

		var mx:Float = FlxG.mouse.screenX;
		var my:Float = FlxG.mouse.screenY;

		// 1) ¿Tocó un evento ya colocado? -> seleccionarlo
		for (lane in laneEvents)
			for (ev in lane)
				if (FlxG.mouse.overlaps(ev)) { selectEvent(ev); return; }

		// 2) ¿Tocó un cuadro vacío? -> colocar el evento elegido en el dropdown, cuantizado al step
		for (box in visibleBoxes)
		{
			if (mx >= box.x && mx <= box.x + box.w && my >= box.y && my <= box.y + box.h)
			{
				var name:String = eventDropDown.list[Std.int(Math.max(eventDropDown.selectedIndex, 0))];
				addEvent(name, value1Input.text, value2Input.text, box.lane, box.time);
				return;
			}
		}
	}

	function repositionEvents()
	{
		for (lane in laneEvents)
			for (ev in lane)
				if (ev != null)
					ev.y = (ev.strumTime - scrollTime) * PIXELS_PER_MS - ev.height / 2;
	}

	function updatePlayhead()
	{
		playhead.y = (Conductor.songPosition - scrollTime) * PIXELS_PER_MS;
	}

	// ---------------- Preview de sonidos ----------------

	function checkAlertPreview()
	{
		var now:Float = Conductor.songPosition;
		for (lane in laneEvents)
		{
			for (ev in lane)
			{
				if (now > ev.strumTime && lastCheckedTime <= ev.strumTime)
				{
					for (sub in ev.events)
						playEventPreview(sub[0], sub[1]);
				}
			}
		}
		lastCheckedTime = now;
	}

	function playEventPreview(eventName:String, value1:String)
	{
		switch (eventName)
		{
			case 'KB_Alert':
				FlxG.sound.play(Paths.sound('mechanics/alerts/$SOUND_SKIN/' + soundByIndex(ALERT_SOUNDS, value1)));
			case 'KB_AlertDouble':
				FlxG.sound.play(Paths.sound('mechanics/alerts/$SOUND_SKIN/alertDouble'));
			case 'Careless_Alert':
				FlxG.sound.play(Paths.sound('mechanics/alerts/$SOUND_SKIN/alert'));
			case 'KB_AttackFire':
				FlxG.sound.play(Paths.sound('mechanics/attacks/$SOUND_SKIN/' + soundByIndex(ATTACK_SOUNDS, value1)));
			case 'KB_AttackFireDOUBLE':
				FlxG.sound.play(Paths.sound('mechanics/attacks/$SOUND_SKIN/attack-double'));
		}
	}

	function soundByIndex(list:Array<String>, value1:String):String
	{
		var idx:Null<Int> = Std.parseInt(value1);
		if (idx == null || idx < 1 || idx > list.length) idx = 1;
		return list[idx - 1];
	}

	// ---------------- Textos ----------------

	function updateTexts()
	{
		headerText.text = 'Editor de Eventos KB — Tiempo: ${Math.floor(Conductor.songPosition)} ms';

		for (i in 0...LANE_COUNT)
			laneLabels[i].color = (i == activeLane) ? FlxColor.LIME : FlxColor.WHITE;

		var sel:String = 'Nada seleccionado. Toca un cuadro para colocar el evento elegido arriba, o toca un evento existente para editarlo.';
		if (selectedEvent != null)
		{
			var d = selectedEvent.events[0];
			sel = 'Seleccionado: ${d[0]}  (edita Value 1 / Value 2 arriba)';
		}
		infoText.text = 'Carril activo: ${LANE_NAMES[activeLane]} (toca A/B/C arriba)\n' + sel;
	}

	// ---------------- Guardado ----------------

	function saveEvents()
	{
		var all:Array<EventMetaNote> = [];
		for (lane in laneEvents) all = all.concat(lane);
		all.sort((a, b) -> a.strumTime < b.strumTime ? -1 : (a.strumTime > b.strumTime ? 1 : 0));

		PlayState.SONG.events = [for (ev in all) [ev.strumTime, ev.events]];

		var chartData:String = PsychJsonPrinter.print(PlayState.SONG, ['sectionNotes', 'events']);
		#if mobile
		var chartName:String = Paths.formatToSongPath(PlayState.SONG.song) + '.json';
		StorageUtil.saveContent(chartName, chartData);
		#else
		if (Song.chartPath != null)
			File.saveContent(Song.chartPath, chartData);
		#end
	}

	function closeEditor()
	{
		FlxG.sound.music.stop();
		vocals.stop();
		opponentVocals.stop();
		MusicBeatState.switchState(new states.editors.ChartingState());
	}
}
