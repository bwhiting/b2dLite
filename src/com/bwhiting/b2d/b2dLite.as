package com.bwhiting.b2d 
{
	import flash.display.BitmapData;
	import flash.display.BlendMode;
	import flash.display.Stage;
	import flash.display.Stage3D;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DBlendFactor;
	import flash.display3D.Context3DCompareMode;
	import flash.display3D.Context3DProgramType;
	import flash.display3D.Context3DTextureFormat;
	import flash.display3D.Context3DVertexBufferFormat;
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.Program3D;
	import flash.display3D.textures.Texture;
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	/**
	 * ...
	 * @author bwhiting
	 */
	public class b2dLite 
	{
		//callback
		private var _onReady			:Function; 
		
		//context
		private var _stage				:Stage;
		private var _stage3D			:Stage3D;
		private var _context3D			:Context3D;
		private var _antiAlias			:int;
		
		//variables
		private var _width				:Number;
		private var _height				:Number;
		private var _aspect				:Number;
		
		//geom
		private var _quadIds			:Vector.<uint>;
		private var _quadVertices		:Vector.<Number>;
		private var _quadUVs			:Vector.<Number>;
		private var _quadOffsets		:Vector.<Number>;
		
		//buffers
		private var _quadIndexBuffer	:IndexBuffer3D;
		private var _quadPositionBuffer	:VertexBuffer3D;
		private var _quadUVBuffer		:VertexBuffer3D;
		private var _quadOffsetBuffer	:VertexBuffer3D;
		
		//program
		private var _quadProgram		:Program3D;
		
		//texture pointer
		private var _texture			:Texture;
		
		//constants
		private var _vertexConstants	:Vector.<Number>;
		
		//utils
		private var matrix				:Matrix = new Matrix();
		
		//pool of draw calls, perhaps bytearray could be used with fastmem + writeBytes for faster GPU
		private var drawCallPool		:Vector.<Number>;
		private var drawCallPoolIndex	:int;

		//register shizzle
		private var _numRegisters			:int = 128;
		private var _registersPerInstance	:int = 2;
		private var _registerUseage			:int = 0;
		private var _maxInstances			:int = 0;		
		
		public function b2dLite(antiAlias:uint = 4)
		{
			_antiAlias = antiAlias;
			drawCallPool = new Vector.<Number>();
		}
		
		public function initializeFromStage(stage:Stage, onReady:Function, width:Number = NaN, height:Number = NaN):void
		{
			_stage = stage;
			_onReady = onReady;
			
			_width = isNaN(width) ? _stage.stageWidth : width;
			_height = isNaN(height) ? _stage.stageHeight : height;
			
			_stage3D = _stage.stage3Ds[0];
			_stage3D.addEventListener(Event.CONTEXT3D_CREATE, onContext);
			_stage3D.requestContext3D();
		}
		public function initializeFromContext(context:Context3D, width:Number, height:Number):void
		{
			_context3D = context;
			_width = width;
			_height = height;
			init();
		}
		private function onContext(e:Event):void
		{
			_context3D = _stage3D.context3D;
			init();
		}
		public function get context():Context3D
		{
			return _context3D;
		}
		private function init():void
		{			
			_context3D.enableErrorChecking = false;
			_context3D.configureBackBuffer(_width, _height, _antiAlias, false);
			_context3D.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA, Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
			_context3D.setDepthTest(false, Context3DCompareMode.ALWAYS);

			_aspect = _width / _height;
			
			_maxInstances = (_numRegisters / _registersPerInstance) - _registerUseage;
			_vertexConstants = new Vector.<Number>(_numRegisters * 4, true);			
			
			var id:int
			_quadIds = new Vector.<uint>();
			for (var i:int = 0; i < _maxInstances; i++) {
				id = i * 4;
				_quadIds.push(id, id+1, id+2, id+3, id+2, id+1);	
			}			
			_quadVertices = new Vector.<Number>();
			for (i = 0; i < _maxInstances; i++)	_quadVertices.push(-1, 1, 1, 1, -1, -1, 1, -1);			
			_quadUVs = new Vector.<Number>();
			for (i = 0; i < _maxInstances; i++)	_quadUVs.push(0, 0, 1, 0, 0, 1, 1, 1);
			_quadOffsets = new Vector.<Number>();
			for (i = 0; i < _maxInstances; i++)
			{
				id = 0 + (i * 2);
				_quadOffsets.push( id, id +1, id, id + 1, id, id +1, id, id + 1);
			}
			
			_quadIndexBuffer = _context3D.createIndexBuffer(_quadIds.length);
			_quadIndexBuffer.uploadFromVector(_quadIds, 0, _quadIds.length );			
			_quadPositionBuffer = _context3D.createVertexBuffer(_quadVertices.length / 2, 2);
			_quadPositionBuffer.uploadFromVector(_quadVertices, 0, _quadVertices.length / 2);			
			_quadUVBuffer = _context3D.createVertexBuffer(_quadUVs.length / 2, 2);
			_quadUVBuffer.uploadFromVector(_quadUVs, 0, _quadUVs.length / 2);
			_quadOffsetBuffer = _context3D.createVertexBuffer(_quadOffsets.length / 2, 2);
			_quadOffsetBuffer.uploadFromVector(_quadOffsets, 0, _quadOffsets.length / 2);
			
			//Compile shaders
        	var decodeFragment:Array = [-96,1,0,0,0,-95,1,40,0,0,0,0,0,15,3,0,0,0,-28,4,0,0,0,0,0,0,0,5,0,16,16];
			var decodeVertex:Array = [-96,1,0,0,0,-95,0,0,0,0,0,0,0,15,2,0,0,0,-28,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,3,2,2,0,0,84,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,3,2,0,0,0,84,2,0,0,0,1,0,0,84,1,2,0,-128,1,0,0,0,0,0,3,2,0,0,0,84,2,0,0,0,1,0,0,-2,1,2,0,-128,0,0,0,0,0,0,15,3,0,0,0,-28,2,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,3,2,1,0,0,84,0,0,0,0,1,0,0,84,1,2,1,-128,1,0,0,0,0,0,15,4,0,0,0,84,2,0,0,0,1,0,0,-2,1,2,1,-128];		
			
			var fragmentProgram:ByteArray = new ByteArray;
			fragmentProgram.endian = Endian.LITTLE_ENDIAN;
			for (var i:int = 0; i < decodeFragment.length; i++) fragmentProgram.writeByte(decodeFragment[i]); fragmentProgram.position = 0;
            var vertexProgram:ByteArray = new ByteArray;
			vertexProgram.endian = Endian.LITTLE_ENDIAN;
			for (var i:int = 0; i < decodeVertex.length; i++) vertexProgram.writeByte(decodeVertex[i]); vertexProgram.position = 0;
						
			_quadProgram = _context3D.createProgram();
			_quadProgram.upload(vertexProgram, fragmentProgram);
			
			//set buffers
			_context3D.setVertexBufferAt(0, _quadPositionBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			_context3D.setVertexBufferAt(1, _quadUVBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			_context3D.setVertexBufferAt(2, _quadOffsetBuffer, 0, Context3DVertexBufferFormat.FLOAT_2);
			
			//set program
			_context3D.setProgram(_quadProgram);
			
			if(_onReady)	_onReady();
		}
		public function clear(r:Number = 0, g:Number = 0, b:Number = 0, a:Number = 1):void
		{
			_context3D.clear(r, g, b, a);
		}
		public function present():void
		{
			flush();
			_context3D.present();
		}
		public final function renderQuad(width:Number, height:Number, x:Number, y:Number, texture:Texture, textureScaleX:Number = 1, textureScaleY:Number = 1, textureOffsetX:Number = 0,  textureOffsetY:Number = 0):void
		{
			if (texture != _texture)
			{
				flush();
				_texture = texture;
				_context3D.setTextureAt(0, _texture);				
			}			
			var index:int = drawCallPoolIndex;
			drawCallPool[drawCallPoolIndex] 		= x - _width * 0.5;
			drawCallPool[int(drawCallPoolIndex + 1)] = y - _height * 0.5;
			drawCallPool[int(drawCallPoolIndex + 2)] = width;
			drawCallPool[int(drawCallPoolIndex + 3)] = height;
			drawCallPool[int(drawCallPoolIndex + 4)] = textureScaleX;
			drawCallPool[int(drawCallPoolIndex + 5)] = textureScaleY;
			drawCallPool[int(drawCallPoolIndex + 6)] = textureOffsetX;
			drawCallPool[int(drawCallPoolIndex + 7)] = textureOffsetY;			
			drawCallPoolIndex += 8;
		}
		private function flush():void
		{
			var offset:int = 0;
			var num:int = 0;
			
			for (var i:int = 0; i < drawCallPoolIndex; i+=8 )
			{
				num++;
				_vertexConstants[offset] 		= drawCallPool[int(i + 2)] / _width;
				_vertexConstants[int(offset + 1)] = drawCallPool[int(i + 3)] / _height;
				_vertexConstants[int(offset + 2)] = (drawCallPool[i] / _width) * 2;
				_vertexConstants[int(offset + 3)] = -(drawCallPool[int(i + 1)] / _height) * 2;
				_vertexConstants[int(offset + 4)] = drawCallPool[int(i + 4)];
				_vertexConstants[int(offset + 5)] = drawCallPool[int(i + 5)];
				_vertexConstants[int(offset + 6)] = drawCallPool[int(i + 6)];
				_vertexConstants[int(offset + 7)] = drawCallPool[int(i + 7)];
				
				offset += 8;
				
				if (num > _maxInstances - 1)
				{
					_context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, _vertexConstants);
					_context3D.drawTriangles(_quadIndexBuffer, 0, num * 2);
					num = 0;
					offset = 0;
				}
			}			
			if (num)
			{
				_context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 0, _vertexConstants);
				_context3D.drawTriangles(_quadIndexBuffer, 0, num * 2);
			}
			drawCallPoolIndex = 0;		
		}
		public function createTexture(image:BitmapData):Texture
		{
			var texture:Texture = _context3D.createTexture(image.width, image.height, Context3DTextureFormat.BGRA, false);
			texture.uploadFromBitmapData(image, 0);
			return texture;
		}
	}
}