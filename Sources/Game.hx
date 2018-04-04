import kha.System;
import kha.Framebuffer;
import kha.Color;
import kha.Shaders;
import kha.Image;
import kha.Assets;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexData;
import kha.graphics4.ConstantLocation;
import kha.graphics4.TextureUnit;
import kha.graphics4.CullMode;
import kha.graphics4.CompareMode;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.Usage;
import haxe.ds.Vector;
import gltf.GLTF;
import gltf.types.AnimationChannel;
import glm.GLM;
import glm.Mat4;
import glm.Vec4;
import glm.Vec3;
import glm.Quat;

class Transform {
    public var pos:Vec3 = new Vec3();
    public var rot:Quat = Quat.identity(new Quat());
    public var sca:Vec3 = new Vec3(1, 1, 1);
    public var mat:Mat4 = Mat4.identity(new Mat4());

    public function new() {}

    public function calculate(?parent:Transform):Void {
        mat = GLM.transform(pos, rot, sca, mat);
        if(parent != null) {
            Mat4.multMat(parent.mat, mat, mat);
        }
    }
}

@:allow(Main)
class Game {
	static var pipeline:PipelineState;
	static var mvpID:ConstantLocation;
	static var mID:ConstantLocation;
    static var jointMatricesIDs:Array<ConstantLocation>;
    static var inverseBindMatrices:Array<Mat4>;

    static var mvp:Mat4;
    static var vp:Mat4;
    static var base:Transform;
    static var bones:Array<Transform>;

    static var channels:Vector<AnimationChannel>;

    static var jointMatrices:Array<Mat4>;

    static var vertexBuffer:VertexBuffer;
	static var indexBuffer:IndexBuffer;

    static var t:Float = 0;

    static function initialize():Void {
        var structure = new VertexStructure();
        structure.add("position", VertexData.Float3);
        structure.add("normal", VertexData.Float3);
        structure.add("joints", VertexData.Float4);
        structure.add("weights", VertexData.Float4);

		pipeline = new PipelineState();
		pipeline.inputLayout = [structure];
		pipeline.vertexShader = Shaders.skin_vert;
		pipeline.fragmentShader = Shaders.skin_frag;
        pipeline.cullMode = CullMode.Clockwise;
        pipeline.depthMode = CompareMode.Less;
        pipeline.depthWrite = true;

        try {
            pipeline.compile();
        }
        catch(e:String) {
            #if js
            js.Browser.console.error(e);
            #else
            trace('ERROR:');
            trace(e);
            #end
        }

		mvpID = pipeline.getConstantLocation("MVP");
		mID = pipeline.getConstantLocation("M");
        jointMatricesIDs = new Array<ConstantLocation>();
        jointMatricesIDs.push(pipeline.getConstantLocation("jointMatrices[0]"));
        jointMatricesIDs.push(pipeline.getConstantLocation("jointMatrices[1]"));

        var riggedSimple:GLTF = GLTF.parseAndLoad(Assets.blobs.RiggedSimple_gltf.toString(), [
            Assets.blobs.RiggedSimple0_bin.bytes
        ]);

        var positions:Vector<Float> = riggedSimple.meshes[0].primitives[0].getFloatAttributeValues("POSITION");
        var normals:Vector<Float> = riggedSimple.meshes[0].primitives[0].getFloatAttributeValues("NORMAL");
        var joints:Vector<Int> = riggedSimple.meshes[0].primitives[0].getIntAttributeValues("JOINTS_0");
        var weights:Vector<Float> = riggedSimple.meshes[0].primitives[0].getFloatAttributeValues("WEIGHTS_0");
        var indices:Vector<Int> = riggedSimple.meshes[0].primitives[0].getIndexValues();

        var numVerts:Int = Std.int(positions.length / 3);

        vertexBuffer = new VertexBuffer(numVerts, structure, Usage.StaticUsage);
        var vbData = vertexBuffer.lock();
        for(v in 0...numVerts) {
            vbData[(v * 14) + 0] = positions[(v * 3) + 0];
            vbData[(v * 14) + 1] = positions[(v * 3) + 1];
            vbData[(v * 14) + 2] = positions[(v * 3) + 2];

            vbData[(v * 14) + 3] = normals[(v * 3) + 0];
            vbData[(v * 14) + 4] = normals[(v * 3) + 1];
            vbData[(v * 14) + 5] = normals[(v * 3) + 2];

            vbData[(v * 14) + 6] = joints[(v * 4) + 0];
            vbData[(v * 14) + 7] = joints[(v * 4) + 1];
            vbData[(v * 14) + 8] = joints[(v * 4) + 2];
            vbData[(v * 14) + 9] = joints[(v * 4) + 3];

            vbData[(v * 14) + 10] = weights[(v * 4) + 0];
            vbData[(v * 14) + 11] = weights[(v * 4) + 1];
            vbData[(v * 14) + 12] = weights[(v * 4) + 2];
            vbData[(v * 14) + 13] = weights[(v * 4) + 3];
        }
        vertexBuffer.unlock();

		indexBuffer = new IndexBuffer(indices.length, Usage.StaticUsage);
		var iData = indexBuffer.lock();
		for (i in 0...iData.length) {
			iData[i] = indices[i];
		}
		indexBuffer.unlock();

        mvp = new Mat4();
        base = new Transform();
        base.calculate();
        var v:Mat4 = GLM.lookAt(
            new Vec3(10, 10, 10),
            new Vec3(0, 0, 0),
            new Vec3(0, 0, 1),
            new Mat4()
        );
        var p:Mat4 = GLM.perspective(
            49 * Math.PI / 180,
            System.windowWidth() / System.windowHeight(),
            0.1, 100,
            new Mat4()
        );
        vp = Mat4.multMat(p, v, new Mat4());

        inverseBindMatrices = new Array<Mat4>();
        inverseBindMatrices.push(Mat4.fromFloatArray(riggedSimple.skins[0].inverseBindMatrices[0].toArray()));
        inverseBindMatrices.push(Mat4.fromFloatArray(riggedSimple.skins[0].inverseBindMatrices[1].toArray()));

        bones = new Array<Transform>();
        bones.push(new Transform());
        bones.push(new Transform());

        jointMatrices = new Array<Mat4>();
        jointMatrices.push(Mat4.identity(new Mat4()));
        jointMatrices.push(Mat4.identity(new Mat4()));

        channels = riggedSimple.animations[0].channels;
    }

    static function sample(t:Float, samples:Vector<AnimationSample>):Vector<Float> {
        if(t < samples[0].input) return samples[0].output;
        if(t > samples[samples.length - 1].input) return samples[samples.length - 1].output;

        // find the two points to interpolate between
        var j:Int = 0;
        var alpha:Float = 0.0;
        for(i in 0...(samples.length - 1)) {
            if(t >= samples[i].input && t < samples[i + 1].input) {
                j = i;
                alpha = (t - samples[i].input) / (samples[i + 1].input - samples[i].input);
                break;
            }
        }

        var output:Vector<Float> = new Vector<Float>(samples[0].output.length);
        for(i in 0...output.length) {
            output[i] = GLM.lerp(samples[j].output[i], samples[j + 1].output[i], alpha);
        }
        
        return output;
    }

    static function update():Void {
        for(channel in channels) {
            switch(channel.path) {
                case TRANSLATION: {
                    var translation:Vector<Float> = sample(t, channel.samples);
                    bones[channel.node.id - 2].pos.x = translation[0];
                    bones[channel.node.id - 2].pos.y = translation[1];
                    bones[channel.node.id - 2].pos.z = translation[2];
                }

                case ROTATION: {
                    var rotation:Vector<Float> = sample(t, channel.samples);
                    bones[channel.node.id - 2].rot.x = rotation[0];
                    bones[channel.node.id - 2].rot.y = rotation[1];
                    bones[channel.node.id - 2].rot.z = rotation[2];
                    bones[channel.node.id - 2].rot.w = rotation[3];
                }

                case SCALE: {
                    var scale:Vector<Float> = sample(t, channel.samples);
                    bones[channel.node.id - 2].sca.x = scale[0];
                    bones[channel.node.id - 2].sca.y = scale[1];
                    bones[channel.node.id - 2].sca.z = scale[2];
                }

                default: {}
            }
        }

        Quat.multiplyQuats(Quat.fromEuler(0, 0, -0.25 * (1 / 60), new Quat()), base.rot, base.rot);
        base.calculate();
        bones[0].calculate(base);
        bones[1].calculate(bones[0]);
    
        Mat4.multMat(bones[0].mat, inverseBindMatrices[0], jointMatrices[0]);
        Mat4.multMat(bones[1].mat, inverseBindMatrices[1], jointMatrices[1]);

        Mat4.multMat(vp, base.mat, mvp);

        t += 1 / 60;
        if(t >= 2) {
            t = 0;
        }
    }

    static function render(fb:Framebuffer):Void {
        var g = fb.g4;

        g.begin();
        g.clear(Color.Black, 1);
        g.setPipeline(pipeline);

        g.setMatrix(mvpID, mvp);
        g.setMatrix(mID, base.mat);
        g.setMatrix(jointMatricesIDs[0], jointMatrices[0]);
        g.setMatrix(jointMatricesIDs[1], jointMatrices[1]);

        g.setVertexBuffer(vertexBuffer);
        g.setIndexBuffer(indexBuffer);
        g.drawIndexedVertices();
    }
}
