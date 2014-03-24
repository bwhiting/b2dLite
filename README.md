b2dLite
=======

A quick and dirty stage3d quad rendering engine. It will batch your draw calls automatically, so to take advantage of it fully USE SPRITESHEETS and draw objects with the same textures together and you should be golden.



To use this class do the following:

1. Create an instance of b2dLite
	b2d = new b2dLite();


2. Initialize it using one of two methods, initializeFromStage or initializeFromContext
	b2d.initializeFromStage(stage, start, 512, 512);		//stage, callback when ready, width, height


3. After the callback, you can start to draw things, but first you need to create a texture
	texture = b2d.createTexture(textureMap);		//pass in a valid bitmapData


4. Remeber to clear the buffer every frame
	b2d.clear();


5. Draw something!
	b2d.renderQuad(32, 32, stage.mouseX, stage.mouseY, texture);


6. Once you have finished drawing present the buffer to the screen
	b2d.present();



Example App

```actionscript3
package
{
	import com.bwhiting.b2d.b2dLite;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display3D.textures.Texture;
	import flash.events.Event;
	
	/**
	 * ...
	 * @author bwhiting
	 */
	public class Main extends Sprite 
	{
		private var b2d:b2dLite;
		private var textureMap:BitmapData;
		private var texture:Texture;
		
		public function Main():void 
		{
			if (stage) init();
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(e:Event = null):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, init);
			// entry point			
			b2d = new b2dLite();
			b2d.initializeFromStage(stage, start, 512, 512);
		}
		private function start():void 
		{
			textureMap = new BitmapData(32, 32, false, 0xFF0000);
			texture = b2d.createTexture(textureMap);
			
			stage.addEventListener(Event.ENTER_FRAME, update);
		}
		
		private function update(e:Event):void 
		{
			//clear
			b2d.clear();
			//draw stuff
			b2d.renderQuad(32, 32, stage.mouseX, stage.mouseY, texture);
			//present
			b2d.present();
		}		
	}	
}
```

In the above example you can check out performance by adding the following line after the comment "//draw stuff":


for (var i:int = 0; i < 5000; i++)	b2d.renderQuad(2, 2, Math.random() * 512, Math.random() * 512, texture);


On my mid-range machine I can crank that number up to 15000 and still hit 60fps no probs
