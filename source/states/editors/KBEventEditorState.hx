package states.editors;

import flixel.input.keyboard.FlxKey;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.util.FlxColor;
import flixel.ui.FlxButton;

import backend.ui.PsychUIInputText;
import states.editors.content.MetaNote;
import states.editors.content.*; // trae EventMetaNote

/**
 * Editor de eventos con 3 carriles independientes, con botones táctiles
 * (funcionan igual con mouse en PC y con el dedo en Android).
 * NO tiene barra de flechas / grid de notas: solo trabaja con PlayState.SONG.events.
 */
class KBEventEditorState extends MusicBeatState
{
	static inline final LANE_COUNT:Int = 3;
	static final LANE_X:Array<Float> = [200, 500, 800];
	static final LANE_NAMES:Array<String> = ['Carril A', 'Carril B', 'Carril C'];
	static inline final PIXELS_PER_MS:Float = 0.25;

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

	// Mismos atajos pero por teclado físico, para cuando se usa en PC
	static final KB_HOTKEYS:Map<FlxKey, Int> = [
		ONE => 0, TWO => 1, THREE => 2, FOUR => 3,
		P => 4, F => 5, C => 6, N => 7, M => 8,
	];

	static final ALERT_SOUNDS:Array<String> = ['alert', 'alertDouble', 'alertTriple', 'alertQuadruple', 'alertQuintuple', 'alertSixtuple'];

	var laneEvents:Array<Array<EventMetaNote>> = [[], [], []];
	var laneGroup:FlxTypedGroup<EventMetaNote> = new FlxTypedGroup<EventMetaNote>();
	var laneLabels:Array<FlxText> = [];

	var activeLane:Int = 0;
	var scrollTime:Float = 0;
	var lastCheckedTime:Float = 0;

	var playhead:FlxSprite;
	var infoText:FlxText;
	var headerText:FlxText;
	var selectedEvent:EventMetaNote = null;

	// UI táctil
	var laneButtons:Array<FlxButton> = [];
	var eventButtons:Array<FlxButton> = [];
	var playPauseButton:FlxButton;
	var saveButton:FlxButton;
	var closeButton:FlxButton;
	var nameLeftButton:FlxButton;
	var nameRightButton:FlxButton;
	var deleteButton:FlxButton;

	var value1Input:PsychUIInputText;
	var value2Input:PsychUIInputText;
	var value1Label:FlxText;
	var value2Label:FlxText;

	override function create()
	{
		Conductor.songPosition = 0;
		persistentUpdate = persistentDraw = false;

		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.7);
		FlxG.sound.music.pause();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.fromRGB(18, 18, 24));
		bg.scrollFactor.set();
		add(bg);

		for (i in 0...LANE_COUNT)
		{
			var line:FlxSprite = new FlxSprite(LANE_X[i] - 1, 0).makeGraphic(2, FlxG.height, FlxColor.fromRGB(80, 80, 90));
			line.scrollFactor.set();
			add(line);
		}

		add(laneGroup);

		playhead = new FlxSprite(0, 0).makeGraphic(FlxG.width, 2, FlxColor.RED);
		playhead.scrollFactor.set();
		add(playhead);

		headerText = new FlxText(10, 4, FlxG.width - 20, '', 15);
		headerText.color = FlxColor.YELLOW;
		headerText.scrollFactor.set();
		add(headerText);

		buildLaneButtons();
		buildEventButtons();
		buildBottomBar();
		buildValueEditors();

		infoText = new FlxText(10, FlxG.height - 150, FlxG.width - 20, '', 14);
		infoText.scrollFactor.set();
		add(infoText);

		loadExistingEvents();

		super.create();
	}

	// ---------------- UI táctil ----------------

	function buildLaneButtons()
	{
		for (i in 0...LANE_COUNT)
		{
			var btn:FlxButton = new FlxButton(LANE_X[i] - 55, 24, LANE_NAMES[i], function() activeLane = i);
			btn.scrollFactor.set();
			add(btn);
			laneButtons.push(btn);

			var label:FlxText = new FlxText(LANE_X[i] - 55, 50, 110, '', 12);
			label.alignment = CENTER;
			label.scrollFactor.set();
			add(label);
			laneLabels.push(label);
		}
	}

	function buildEventButtons()
	{
		// Fila de botones táctiles con los eventos KB_ más usados
		var startX:Float = 10;
		var y:Float = FlxG.height - 200;
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
		playPauseButton = new FlxButton(10, FlxG.height - 40, 'Play/Pausa', function()
		{
			if (FlxG.sound.music.playing) FlxG.sound.music.pause();
			else FlxG.sound.music.play();
		});
		playPauseButton.scrollFactor.set();
		add(playPauseButton);

		saveButton = new FlxButton(130, FlxG.height - 40, 'Guardar', saveEvents);
		saveButton.scrollFactor.set();
		add(saveButton);

		deleteButton = new FlxButton(250, FlxG.height - 40, 'Borrar', deleteSelected);
		deleteButton.scrollFactor.set();
		add(deleteButton);

		nameLeftButton = new FlxButton(370, FlxG.height - 40, '< Nombre', function() cycleEventName(-1));
		nameLeftButton.scrollFactor.set();
		add(nameLeftButton);

		nameRightButton = new FlxButton(490, FlxG.height - 40, 'Nombre >', function() cycleEventName(1));
		nameRightButton.scrollFactor.set();
		add(nameRightButton);

		closeButton = new FlxButton(FlxG.width - 110, FlxG.height - 40, 'Salir', closeEditor);
		closeButton.scrollFactor.set();
		add(closeButton);
	}

	function buildValueEditors()
	{
		value1Label = new FlxText(610, FlxG.height - 44, 60, 'Value 1:', 12);
		value1Label.scrollFactor.set();
		add(value1Label);

		value1Input = new PsychUIInputText(675, FlxG.height - 46, 90, '', 12);
		value1Input.scrollFactor.set();
		value1Input.onChange = function(_, newText:String)
		{
			if (selectedEvent != null) selectedEvent.events[0][1] = newText;
		};
		add(value1Input);

		value2Label = new FlxText(775, FlxG.height - 44, 60, 'Value 2:', 12);
		value2Label.scrollFactor.set();
		add(value2Label);

		value2Input = new PsychUIInputText(840, FlxG.height - 46, 140, '', 12);
		value2Input.scrollFactor.set();
		value2Input.onChange = function(_, newText:String)
		{
			if (selectedEvent != null) selectedEvent.events[0][2] = newText;
		};
		add(value2Input);
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

	function addEvent(name:String, value1:String, value2:String, lane:Int)
	{
		var time:Float = Conductor.songPosition;
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
		}
		else
		{
			value1Input.text = '';
			value2Input.text = '';
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

	function cycleEventName(dir:Int)
	{
		if (selectedEvent == null) return;
		var data = selectedEvent.events[0];
		var names:Array<String> = [for (e in ChartingState.defaultEvents) e[0]];
		var curIndex:Int = names.indexOf(data[0]);
		curIndex = (curIndex < 0) ? 0 : ((curIndex + dir + names.length) % names.length);
		data[0] = names[curIndex];
		selectedEvent.updateEventText();
	}

	// ---------------- Loop principal ----------------

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		handleTransportKeys(elapsed);
		handleHotkeys();
		handleTapSelect();
		repositionEvents();
		updatePlayhead();
		checkAlertPreview();
		updateTexts();

		if (FlxG.keys.justPressed.ESCAPE) closeEditor();
		if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.S) saveEvents();
	}

	function handleTransportKeys(elapsed:Float)
	{
		if (FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;
		else
		{
			if (FlxG.keys.pressed.RIGHT) Conductor.songPosition += 2000 * elapsed;
			if (FlxG.keys.pressed.LEFT)  Conductor.songPosition -= 2000 * elapsed;
			Conductor.songPosition = Math.max(0, Conductor.songPosition);
			FlxG.sound.music.time = Conductor.songPosition;
		}

		scrollTime = Conductor.songPosition - (FlxG.height / 2) / PIXELS_PER_MS;
	}

	function handleHotkeys()
	{
		// Solo para PC con teclado físico; en Android se usan los botones táctiles
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

	function handleTapSelect()
	{
		// Si el toque no cayó sobre ningún botón/campo de texto, revisa si tocó un evento en el timeline
		if (FlxG.mouse.justPressed && PsychUIInputText.focusOn == null)
		{
			var found:EventMetaNote = null;
			for (lane in laneEvents)
				for (ev in lane)
					if (FlxG.mouse.overlaps(ev)) { found = ev; break; }
			if (found != null) selectEvent(found);
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
						playAlertPreview(sub[0], sub[1]);
				}
			}
		}
		lastCheckedTime = now;
	}

	function playAlertPreview(eventName:String, value1:String)
	{
		switch (eventName)
		{
			case 'KB_Alert':
				var idx:Null<Int> = Std.parseInt(value1);
				if (idx == null || idx < 1 || idx > ALERT_SOUNDS.length) idx = 1;
				FlxG.sound.play(Paths.sound('mechanics/alerts/Kade/${ALERT_SOUNDS[idx - 1]}'));
			case 'KB_AlertDouble':
				FlxG.sound.play(Paths.sound('mechanics/alerts/Kade/alertDouble'));
			case 'Careless_Alert':
				FlxG.sound.play(Paths.sound('mechanics/alerts/Kade/alert'));
		}
	}

	function updateTexts()
	{
		headerText.text = 'Editor de Eventos KB — Tiempo: ${Math.floor(Conductor.songPosition)} ms';

		for (i in 0...LANE_COUNT)
			laneLabels[i].color = (i == activeLane) ? FlxColor.LIME : FlxColor.WHITE;

		var sel:String = 'Nada seleccionado. Toca un evento en el timeline para editarlo.';
		if (selectedEvent != null)
		{
			var d = selectedEvent.events[0];
			sel = 'Seleccionado: ${d[0]}  (toca los campos Value 1 / Value 2 para escribir)';
		}
		infoText.text = 'Carril activo: ${LANE_NAMES[activeLane]} (toca A/B/C arriba)\n' + sel;
	}

	function saveEvents()
	{
		var all:Array<EventMetaNote> = [];
		for (lane in laneEvents) all = all.concat(lane);
		all.sort((a, b) -> a.strumTime < b.strumTime ? -1 : (a.strumTime > b.strumTime ? 1 : 0));

		PlayState.SONG.events = [for (ev in all) ev.songData];

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
		MusicBeatState.switchState(new states.editors.ChartingState());
	}
}
