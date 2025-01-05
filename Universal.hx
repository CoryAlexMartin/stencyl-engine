package;

import openfl.Lib;
import openfl.display.Sprite;
import openfl.display.Stage;
import openfl.display.StageAlign;
import openfl.display.StageScaleMode;
import openfl.display.StageDisplayState;
import openfl.display.Shape;
import openfl.display.BitmapData;
import openfl.events.Event;
import lime.ui.Window;
import flash.geom.Matrix;

import com.stencyl.Config;
import com.stencyl.Engine;
import com.stencyl.graphics.Scale;
import com.stencyl.graphics.ScaleMode;
import com.stencyl.utils.Log;

class Universal extends Sprite 
{
	private static var window:Window;
	public static var logicalWidth = 0.0;
	public static var logicalHeight = 0.0;
	public static var windowWidth = 0.0;
	public static var windowHeight = 0.0;
	public static var leftInset = 0.0;
	public static var topInset = 0.0;
	public static var rightInset = 0.0;
	public static var bottomInset = 0.0;

	public static var tile : BitmapData = null;
	
	public var maskLayer:Shape;

	public static function initWindow(window:Window):Void
	{
		Universal.window = window;

		window.stage.align = StageAlign.TOP_LEFT;
		window.stage.scaleMode = StageScaleMode.NO_SCALE;
		
		#if mobile
		window.stage.opaqueBackground = 0x000000;
		#end
	}

	public function new() 
	{
		super();
		name = "Root";

		addEventListener(Event.ADDED_TO_STAGE, onAdded);
	}
	
	private function onAdded(event:Event):Void 
	{
		removeEventListener(Event.ADDED_TO_STAGE, onAdded);
		
		maskLayer = new Shape();
		maskLayer.name = "Mask Layer";
		initScreen(Config.startInFullScreen);
	}

	//isFullScreen is used on Web/Desktop for full screen mode
	#if (!flash) @:access(openfl.display.Stage.__setLogicalSize) #end
	public function initScreen(isFullScreen:Bool)
	{
		Log.debug("initScreen");

		#if mobile
		isFullScreen = true;
		#end
		
		#if html5
		isFullScreen = false;
		#end

		stage.displayState = isFullScreen ?
			StageDisplayState.FULL_SCREEN_INTERACTIVE :
			StageDisplayState.NORMAL;
		
		#if !flash
		stage.__setLogicalSize (0, 0);
		#end

		var isTateMode = Math.abs(rotation) == 90;

		#if desktop
		if(!isFullScreen)
		{
			if (isTateMode) window.resize(Std.int(Config.stageHeight * Config.gameScale), Std.int(Config.stageWidth * Config.gameScale));
			// else            window.resize(Std.int(Config.stageWidth * Config.gameScale), Std.int(Config.stageHeight * Config.gameScale));
		}
		#end

		Lib.current.x = 0;
		Lib.current.y = 0;
		Lib.current.scaleX = 1;
		Lib.current.scaleY = 1;

		x = 0;
		y = 0;
		scaleX = 1;
		scaleY = 1;
	
		Engine.stage = stage;

		#if desktop
		// Use this instead of stage.fullScreenWidth and stage.fullScreenHeight because those values don't update if the user's resolution changes at runtime.
		var fullScreenWidth  = Std.int(Lib.application.window.display.bounds.width);
		var fullScreenHeight = Std.int(Lib.application.window.display.bounds.height);
		#else
		var fullScreenWidth = stage.fullScreenWidth;
		var fullScreenHeight = stage.fullScreenHeight;
		#end

		//enabled scales
		var scales = new Map<Scale,Bool>();
		for(scale in Config.scales)
		{
			scales.set(scale, true);
		}

		windowWidth = isFullScreen ? fullScreenWidth : window.width;
		windowHeight = isFullScreen ? fullScreenHeight : window.height;

		Log.debug("Game Width: " + Config.stageWidth);
		Log.debug("Game Height: " + Config.stageHeight);
		Log.debug("Game Scale: " + Config.gameScale);
		Log.debug("Window Width: " + windowWidth);
		Log.debug("Window Height: " + windowHeight);
		Log.debug("FullScreen Width: " + fullScreenWidth);
		Log.debug("FullScreen Height: " + fullScreenHeight);
		Log.debug("Device Pixel Ratio: " + stage.window.scale);
		Log.debug("Enabled Scales: " + Config.scales);
		Log.debug("Scale Mode: " + Config.scaleMode);
		
		var visualGameW : Int;
		var visualGameH : Int;
		if (isTateMode) {
			visualGameW = Config.stageHeight;
			visualGameH = Config.stageWidth;
		}
		else {
			visualGameW = Config.stageWidth;
			visualGameH = Config.stageHeight;
		}
		var allow1point5 : Bool = #if leapin_lads false #else true #end;
		var theoreticalWindowedScale   = getDesiredScale(windowWidth, windowHeight, visualGameW, visualGameH, allow1point5);
		var theoreticalFullscreenScale = getDesiredScale(fullScreenWidth, fullScreenHeight, visualGameW, visualGameH, allow1point5);
		
		var theoreticalScale = Config.forceHiResAssets ? theoreticalFullscreenScale : theoreticalWindowedScale;
		
		//4 scale scheme
		if(theoreticalScale == 4 && scales.exists(Scale._4X))
		{
			Engine.SCALE = 4;
			Engine.IMG_BASE = "4x";
		}
		
		else if(theoreticalScale >= 3 && scales.exists(Scale._3X))
		{
			Engine.SCALE = 3;
			Engine.IMG_BASE = "3x";
		}
		
		else if(theoreticalScale >= 2 && scales.exists(Scale._2X))
		{
			Engine.SCALE = 2;
			Engine.IMG_BASE = "2x";
		}
		
		else if(theoreticalScale >= 1.5 && scales.exists(Scale._1_5X))
		{
			Engine.SCALE = 1.5;
			Engine.IMG_BASE = "1.5x";
		}
		
		else
		{
			Engine.SCALE = 1;
			Engine.IMG_BASE = "1x";
		}
		
		Log.debug("Theoretical Scale: " + theoreticalScale);
		Log.debug("Asset Scale: " + Engine.IMG_BASE);

		//the dimensions of the game screen after being scaled up
		//to the proper asset size.
		var scaledStageWidth = Config.stageWidth * Engine.SCALE;
		var scaledStageHeight = Config.stageHeight * Engine.SCALE;

		//the remaining x/y scale needed to fit the game screen
		//to the edges of the window.
		var fitWidthScale = windowWidth / scaledStageWidth;
		var fitHeightScale = windowHeight / scaledStageHeight;

		if(Config.forceHiResAssets || windowWidth != Config.stageWidth || windowHeight != Config.stageHeight)
		{
			//after the basic assets scale, how do we fill out the rest of the screen?

			//expand the playable area rather than further scaling it
			if(Config.scaleMode == ScaleMode.FULLSCREEN)
			{
				if(Engine.SCALE != theoreticalWindowedScale)
				{
					scaleX = theoreticalWindowedScale / Engine.SCALE;
					scaleY = scaleX;
				}

				//don't do anything
				//stage width/height are already the size of the screen
			}

			//exactly match the game size to the window size for both width and height
			else if(Config.scaleMode == ScaleMode.STRETCH_TO_FIT)
			{
				scaleX = fitWidthScale;
				scaleY = fitHeightScale;
			}
			
			//keeping aspect ration, stretch until either side of the game screen touches the window's edge
			//for "Scale to fit (fullscreen)", the rest of the space is expanded
			else if(Config.scaleMode == ScaleMode.SCALE_TO_FIT_LETTERBOX || Config.scaleMode == ScaleMode.SCALE_TO_FIT_FULLSCREEN)
			{
				scaleX = Math.min(fitWidthScale, fitHeightScale);
				scaleY = scaleX;
			}
			
			//keeping aspect ration, stretch until both sides of the game screen touch the window's edge
			else if(Config.scaleMode == ScaleMode.SCALE_TO_FIT_FILL)
			{
				scaleX = Math.max(fitWidthScale, fitHeightScale);
				scaleY = scaleX;
			}
			
			//no additional scaling
			else if(Config.scaleMode == ScaleMode.NO_SCALING)
			{
				if(Engine.SCALE != theoreticalWindowedScale)
				{
					scaleX = theoreticalWindowedScale / Engine.SCALE;
					scaleY = scaleX;
				}

				if (!isFullScreen && !isTateMode) {
					x += (windowWidth - scaledStageWidth * scaleX) / 2;
					y += (windowHeight - scaledStageHeight * scaleY) / 2;
				}
			}

			if(isFullScreen && Config.scaleMode != ScaleMode.SCALE_TO_FIT_FULLSCREEN && Config.scaleMode != ScaleMode.FULLSCREEN)
			{
				if (rotation == 90) {
					x += (windowWidth + scaledStageHeight * scaleY) / 2;
					y += (windowHeight - scaledStageWidth * scaleX) / 2;
				}
				else if (rotation == -90) {
					x += (windowWidth - scaledStageHeight * scaleY) / 2;
					y += (windowHeight + scaledStageWidth * scaleX) / 2;
				}
				else {
					x += (windowWidth - scaledStageWidth * scaleX) / 2;
					y += (windowHeight - scaledStageHeight * scaleY) / 2;
				}
			}
			else {
				if      (rotation == -90)  y += scaledStageWidth * scaleX;
				else if (rotation == 90)   x += scaledStageHeight * scaleY;
			}
		}

		logicalWidth = Config.stageWidth;
		logicalHeight = Config.stageHeight;

		if(isFullScreen && (Config.scaleMode == ScaleMode.SCALE_TO_FIT_FULLSCREEN || Config.scaleMode == ScaleMode.FULLSCREEN))
		{
			logicalWidth = (windowWidth / scaleX) / Engine.SCALE;
			logicalHeight = (windowHeight / scaleY) / Engine.SCALE;

			//bring logical size to the nearest full pixel of the desired value.

			if(Std.int(logicalWidth) != logicalWidth || Std.int(logicalHeight) != logicalHeight)
			{
				logicalWidth = Std.int(logicalWidth);
				logicalHeight = Std.int(logicalHeight);

				scaleX = windowWidth / Engine.SCALE / logicalWidth;
				scaleY = windowHeight / Engine.SCALE / logicalHeight;
			}
		}
		
		Engine.screenScaleX = scaleX;
		Engine.screenScaleY = scaleY;

		#if mobile
		var insets = com.stencyl.native.Native.getSafeInsets();
		leftInset = insets.x;
		rightInset = insets.width;
		topInset = insets.y;
		bottomInset = insets.height;
		Log.debug('Safe Area Insets: original = (left: $leftInset, top: $topInset, right: $rightInset, bottom: $bottomInset)');

		if(Config.autorotate)
		{
			/*
			TODO: We don't have a way to notify Stencyl of orientation changes at the moment.
			Eventually, we should have lime listen for and pass on SDL's display events, including
			the orientation one.

			For now, to assure the safe areas are actually safe, we'll mirror the
			max inset along an axis to both sides.
			*/

			leftInset = rightInset = Math.max(leftInset, rightInset);
			topInset = bottomInset = Math.max(topInset, bottomInset);
			Log.debug('Safe Area Insets: mirrored = (left: $leftInset, top: $topInset, right: $rightInset, bottom: $bottomInset)');
		}
		
		if(x != 0 || y != 0)
		{
			// we don't need to inset if we're letterboxing over the inset area.
			leftInset = Math.max(0, leftInset - x);
			rightInset = Math.max(0, rightInset - x);
			topInset = Math.max(0, topInset - y);
			bottomInset = Math.max(0, bottomInset - y);
			Log.debug('Safe Area Insets: offset = (left: $leftInset, top: $topInset, right: $rightInset, bottom: $bottomInset)');
		}
		
		// scale to Stencyl's logical coordinates
		leftInset = Math.ceil(leftInset / (Engine.SCALE * scaleX));
		rightInset = Math.ceil(rightInset / (Engine.SCALE * scaleX));
		topInset = Math.ceil(topInset / (Engine.SCALE * scaleY));
		bottomInset = Math.ceil(bottomInset / (Engine.SCALE * scaleY));

		Log.debug('Safe Area Insets: scaled = (left: $leftInset, top: $topInset, right: $rightInset, bottom: $bottomInset)');

		#end
		
		maskLayer.graphics.clear();

		var sizeMismatch = windowWidth != Config.stageWidth * scaleX || windowHeight != Config.stageHeight * scaleY;
		if (sizeMismatch) {
			//maskLayer is added as a child of Universal later,
			//so it needs to counteract Universal's scaleX/scaleY.
			var spanHor = windowWidth / scaleX;
			var spanVer = windowHeight / scaleY;
			var gameW   = Config.stageWidth;
			var gameH   = Config.stageHeight;

			var padCols : Float;
			var padRows : Float;
			var colLen  : Float;

			if (isTateMode) {
				var hor = spanHor;
				spanHor = spanVer;
				spanVer = hor;
			}

			padCols = (spanHor - gameW) / 2;
			padRows = (spanVer - gameH) / 2;
			colLen  = spanVer - padRows*2;

			maskLayer.graphics.beginFill(stage.color);
			// Draw rectangles          x            y            w         h
			maskLayer.graphics.drawRect(-padCols,    -padRows,    spanHor,  padRows); // top
			maskLayer.graphics.drawRect(-padCols,    0,           padCols,  colLen);  // left
			maskLayer.graphics.drawRect(gameW,       0,           padCols,  colLen);  // right
			maskLayer.graphics.drawRect(-padCols,    gameH,       spanHor,  padRows); // bottom

			if (tile != null) {
				var w = tile.width;

				var matrix = new Matrix();

				// Left
				maskLayer.graphics.beginBitmapFill(tile, matrix, true);

				maskLayer.graphics.drawRect(-w, 0, w, colLen);

				// Right
				matrix.scale(-1, 1);    // Horizontal flip
				matrix.translate(gameW, 0); // Translate back into view
				
				maskLayer.graphics.beginBitmapFill(tile, matrix, true);

				maskLayer.graphics.drawRect(gameW, 0, w, colLen);
			}

			maskLayer.graphics.endFill();
		}
		
		Log.debug("Logical Width: " + logicalWidth);
		Log.debug("Logical Height: " + logicalHeight);
		Log.debug("Scale X: " + scaleX);
		Log.debug("Scale Y: " + scaleY);
		Log.debug("X: " + x);
		Log.debug("Y: " + y);
	}
	
	private function getDesiredScale(checkWidth:Float, checkHeight:Float, baseWidth:Int, baseHeight:Int, allow1point5:Bool = true):Float
	{
		function check(s:Float):Bool
		{
			return (checkWidth >= baseWidth*s && checkHeight >= baseHeight*s);
		} 

		{
			var scale = 16; // Max scale
			while(scale > 1)
			{
				if(check(scale)) return scale;
				scale -= 1;
			}
		}

		if(allow1point5 && check(1.5)) return 1.5;

		return 1;
	}
}
