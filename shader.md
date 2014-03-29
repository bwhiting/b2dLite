Shader
=======

Here is the shader currently used in b2dLite, feel free to have a play around, it is pretty straightforward.


```actionscript3
//AGAL CODE
var vertex_shader:String 		=  "mov vt0 va0 \n";    					//move position into t0
vertex_shader 				+= "mov vt1.xy va2.xy \n";				//move offsets into t1 (used for indirect addressing)
vertex_shader 				+= "mul vt0.xy vt0.xy vc[vt1.x].xy \n";		//scale position
vertex_shader 				+= "add vt0.xy vt0.xy vc[vt1.x].zw \n";		//offset position

vertex_shader 				+= "mov op vt0 \n";					//move position to output position
vertex_shader 				+= "mul vt0.xy va1.xy vc[vt1.y].xy \n";		//scale uvs into t0
vertex_shader 				+= "add v0 vt0.xy vc[vt1.y].zw";			//offset uvs into v0

var fragment_shader:String	=  "tex oc v0 fs0 <2d,linear,repeat>"; 			//set output colour to sampled colour

//SHADER COMPILATION (requires Adobes' AGALMiniAssembler)
var vertexAssembly:AGALMiniAssembler = new AGALMiniAssembler();
var fragmentAssembly:AGALMiniAssembler = new AGALMiniAssembler();

var vertexProgram:ByteArray = vertexAssembly.assemble( Context3DProgramType.VERTEX, vertex_shader, false );
var fragmentProgram:ByteArray = fragmentAssembly.assemble( Context3DProgramType.FRAGMENT, fragment_shader, false );

//How to store a program (vertex is used her) as an as3 array to avoid using the AGALMiniAssembler
var string:String = "";
vertexProgram.position = 0;
var code:Array = [];
while (vertexProgram.bytesAvailable) code.push(vertexProgram.readByte());
trace(code.toString());	//lob that output into an array initializer and boom

```

