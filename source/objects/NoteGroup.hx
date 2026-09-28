package objects;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.group.FlxGroup.FlxTypedGroup;

/**
 * OPTIMIZACION MOBILE: grupo de notas que se DIBUJA carril por carril.
 *
 * Cada carril usa su propia instancia de RGBPaletteShader, y Flixel/OpenFL solo
 * agrupa quads en un mismo draw call si comparten textura Y shader. Como el grupo
 * "notes" esta en orden de tiempo, los carriles se intercalan y casi cada nota
 * rompia el lote (un draw call por nota). Aca solo cambiamos el ORDEN DE DIBUJADO:
 * la lista de miembros, su orden y toda la logica quedan exactamente igual.
 * Los carriles no se solapan visualmente, y dentro de un mismo carril se respeta
 * el orden original (la sustain sigue quedando como estaba respecto a su cabeza).
 */
class NoteGroup extends FlxTypedGroup<Note>
{
	public static inline var LANES:Int = 4;

	override public function draw():Void
	{
		@:privateAccess
		{
			var oldDefaultCameras = FlxCamera._defaultCameras;
			if (_cameras != null)
				FlxCamera._defaultCameras = _cameras;

			for (lane in 0...LANES)
				drawLane(lane, false);

			// notas con noteData fuera de 0...LANES-1 (mods con mas teclas, etc.)
			drawLane(-1, true);

			FlxCamera._defaultCameras = oldDefaultCameras;
		}
	}

	inline function drawLane(lane:Int, others:Bool):Void
	{
		var i:Int = 0;
		var len:Int = members.length;
		while (i < len)
		{
			var note:Note = members[i++];
			if (note != null && note.exists && note.visible)
			{
				var inLane:Bool = others ? (note.noteData < 0 || note.noteData >= LANES) : (note.noteData == lane);
				if (inLane) note.draw();
			}
		}
	}
}
