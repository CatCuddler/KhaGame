package ;

import kha.Framebuffer;
import kha.Color;
import kha.Shaders;
import kha.Assets;
import kha.Image;
import kha.Scheduler;
import kha.System;
import kha.graphics4.TextureUnit;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.FragmentShader;
import kha.graphics4.VertexShader;
import kha.graphics4.VertexData;
import kha.graphics4.Usage;
import kha.graphics4.ConstantLocation;
import kha.graphics4.CompareMode;
import kha.graphics4.CullMode;
import kha.math.FastMatrix4;
import kha.math.FastVector3;
import kha.vr.VrInterface;
import kha.input.KeyCode;

import kha.vr.SensorState;

import js.Browser;

class Empty {

	var debug:Bool = false;

	var vertexBuffer:VertexBuffer;
	var indexBuffer:IndexBuffer;
	var pipeline:PipelineState;

	var projectionID:ConstantLocation;
	var viewID:ConstantLocation;
	var modelID:ConstantLocation;

	var model:FastMatrix4;
	var view:FastMatrix4;
	var projection:FastMatrix4;

	var textureID:TextureUnit;
    var image:Image;

    var lastTime = 0.0;

	var position:FastVector3 = new FastVector3(0, 0, 5); // Initial position: on +Z
	var horizontalAngle = 3.14; // Initial horizontal angle: toward -Z
	var verticalAngle = 0.0; // Initial vertical angle: none

	var vrButton: Dynamic;

	public function new() {
    	// Load all assets defined in khafile.js
    	Assets.loadEverything(loadingFinished);
    }

	function loadingFinished() {
		// Define vertex structure
		var structure = new VertexStructure();
        structure.add("pos", VertexData.Float3);
        structure.add("uv", VertexData.Float2);
        structure.add("nor", VertexData.Float3);
        // Save length - we store position, uv and normal data
        var structureLength = 8;

        // Compile pipeline state
		// Shaders are located in 'Sources/Shaders' directory
        // and Kha includes them automatically
		pipeline = new PipelineState();
		pipeline.inputLayout = [structure];
		pipeline.vertexShader = Shaders.simple_vert;
		pipeline.fragmentShader = Shaders.simple_frag;
		// Set depth mode
        pipeline.depthWrite = true;
        pipeline.depthMode = CompareMode.Less;
        // Set culling
        pipeline.cullMode = CullMode.Clockwise;
		pipeline.compile();

		// Get a handle for our uniforms
		projectionID = pipeline.getConstantLocation("projectionMat");
		viewID = pipeline.getConstantLocation("viewMat");
		modelID = pipeline.getConstantLocation("modelMat");

		// Get a handle for texture sample
		textureID = pipeline.getTextureUnit("diffuse");

		// Texture
		image = Assets.images.tigeratlas;

		// Projection matrix: 45° Field of View, 4:3 ratio, display range : 0.1 unit <-> 100 units
		projection = FastMatrix4.perspectiveProjection(45.0, 4.0 / 3.0, 0.1, 100.0);
		// Or, for an ortho camera
		//projection = FastMatrix4.orthogonalProjection(-10.0, 10.0, -10.0, 10.0, 0.0, 100.0); // In world coordinates
		
		// Camera matrix
		view = FastMatrix4.lookAt(new FastVector3(4, 3, 3), // Camera is at (4, 3, 3), in World Space
							  new FastVector3(0, 0, 0), // and looks at the origin
							  new FastVector3(0, 1, 0) // Head is up (set to (0, -1, 0) to look upside-down)
		);

		// Model matrix: an identity matrix (model will be at the origin)
		model = FastMatrix4.identity();
		var t: FastMatrix4 = FastMatrix4.translation(0, 0, -5);
		model = model.multmat(t);

		// Parse .obj file
		var obj = new ObjLoader(Assets.blobs.tiger_obj.toString());
		var data = obj.data;
		var indices = obj.indices;

		// Create vertex buffer
		vertexBuffer = new VertexBuffer(
			Std.int(data.length / structureLength), // Vertex count
			structure, // Vertex structure
			Usage.StaticUsage // Vertex data will stay the same
		);

		// Copy data to vertex buffer
		var vbData = vertexBuffer.lock();
		for (i in 0...vbData.length) {
			vbData.set(i, data[i]);
		}
		vertexBuffer.unlock();

		// Create index buffer
		indexBuffer = new IndexBuffer(
			indices.length, // Number of indices for our cube
			Usage.StaticUsage // Index data will stay the same
		);
		
		// Copy indices to index buffer
		var iData = indexBuffer.lock();
		for (i in 0...iData.length) {
			iData[i] = indices[i];
		}
		indexBuffer.unlock();

		if(VrInterface.instance.IsVrEnabled()) {
			createResetPoseButton();
			createEnterVrButton();
		}
		// Add keyboard listeners
		kha.input.Keyboard.get().notify(onKeyDown, onKeyUp);

		// Used to calculate delta time
		lastTime = Scheduler.time();
		
		System.notifyOnRender(render);
		Scheduler.addTimeTask(update, 0, 1 / 60);
    }

	public function render(frame: Framebuffer) {
		// A graphics object which lets us perform 3D operations
		var g = frame.g4;

		if (VrInterface.instance.IsPresenting()) {
			// Clear screen
			g.clear();

			for (eye in 0...2) {
				// Begin rendering
				g.beginEye(eye);

				// Bind data we want to draw
				g.setVertexBuffer(vertexBuffer);
				g.setIndexBuffer(indexBuffer);

				// Bind state we want to draw with
				g.setPipeline(pipeline);

				// Set our transformation to the currently bound shader
				projection = VrInterface.instance.GetProjectionMatrix(eye);
				view = VrInterface.instance.GetViewMatrix(eye);
				g.setMatrix(projectionID, projection);
				g.setMatrix(viewID, view);
				g.setMatrix(modelID, model);

				// Set texture
				g.setTexture(textureID, image);

				// Draw!
				g.drawIndexedVertices();

				// End rendering
				g.end();
			}
		} else {
			g.begin();

			// Clear screen
			g.clear();

			// Bind data we want to draw
			g.setVertexBuffer(vertexBuffer);
			g.setIndexBuffer(indexBuffer);

			// Bind state we want to draw with
			g.setPipeline(pipeline);

			// Set our transformation to the currently bound shader
			g.setMatrix(projectionID, projection);
			g.setMatrix(viewID, view);
			g.setMatrix(modelID, model);

			// Set texture
			g.setTexture(textureID, image);

			// Draw!
			g.drawIndexedVertices();

			// End rendering
			g.end();

		}

		
    }

    public function update() {
		// Compute time difference between current and last frame
		var deltaTime = Scheduler.time() - lastTime;
		lastTime = Scheduler.time();

		// Test: get predicted pose
		if (VrInterface.instance.IsPresenting() && debug) {
			var sensorState: SensorState = VrInterface.instance.GetPredictedSensorState(lastTime);

			trace("Angular Vel: " + sensorState.Predicted.AngularVelocity);
			trace("Angular Acc: " + sensorState.Predicted.AngularAcceleration);
			trace("Linear Vel: " + sensorState.Predicted.LinearVelocity);
			trace("Linear Acc: " + sensorState.Predicted.LinearAcceleration);
			trace("Position: " + sensorState.Predicted.Pose.Position);
			trace("Orientation: " + sensorState.Predicted.Pose.Orientation);
		}

		// Direction : Spherical coordinates to Cartesian coordinates conversion
		var direction = new FastVector3(
			Math.cos(verticalAngle) * Math.sin(horizontalAngle),
			Math.sin(verticalAngle),
			Math.cos(verticalAngle) * Math.cos(horizontalAngle)
		);
		
		// Right vector
		var right = new FastVector3(
			Math.sin(horizontalAngle - 3.14 / 2.0), 
			0,
			Math.cos(horizontalAngle - 3.14 / 2.0)
		);
		
		// Up vector
		var up = right.cross(direction);

		// Look vector
		var look = position.add(direction);
		
		// Camera matrix
		view = FastMatrix4.lookAt(position, // Camera is here
							  look, // and looks here : at the same position, plus "direction"
							  up // Head is up (set to (0, -1, 0) to look upside-down)
		);
    }

	// WEB VR Buttons
	private function createEnterVrButton(): Void {
		if (vrButton != null)
			Browser.document.body.removeChild(vrButton);

		vrButton = Browser.document.createButtonElement();
		vrButton.textContent = "Enter VR";
		vrButton.onclick = function(event) {
			VrInterface.instance.onVRRequestPresent();
			onVRPresentChange();
		}
		Browser.document.body.appendChild(vrButton);
	}

	private function createExitVrButton(): Void {
		if (vrButton != null)
			Browser.document.body.removeChild(vrButton);

		vrButton = Browser.document.createButtonElement();
		vrButton.textContent = "Exit VR";
		vrButton.onclick = function(event) {
			VrInterface.instance.onVRExitPresent();
			onVRPresentChange();
		}
		Browser.document.body.appendChild(vrButton);
	}

	private function createResetPoseButton(): Void {
		// Reset pose button
		var resetButton = Browser.document.createButtonElement();
		resetButton.textContent = "Reset Pose!";
		resetButton.onclick = function(event) {
			VrInterface.instance.onResetPose();
		}
		Browser.document.body.appendChild(resetButton);
	}

	private function onVRPresentChange () {
		if (VrInterface.instance.IsPresenting()) {
			createExitVrButton();
		} else {
			createEnterVrButton();
		}
	}

	function onKeyDown(key: kha.input.KeyCode) {
		if(key == KeyCode.E) {
			if (VrInterface.instance.IsPresenting()) {
				VrInterface.instance.onVRExitPresent();
			} else {
				VrInterface.instance.onVRRequestPresent();
			}
		} else if (key == KeyCode.R) {
			VrInterface.instance.onResetPose();
		}
	}

	function onKeyUp(key: kha.input.KeyCode) {

	}
}
