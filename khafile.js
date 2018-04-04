let project = new Project('Animation Test');

project.addSources('Sources');
project.addShaders('Shaders/**');

project.addLibrary('glm');
project.addLibrary('gltf');

project.addAssets('Assets/**');

project.addParameter('-debug');
project.addParameter('--times');
project.addParameter('-D eval-times');

// HTML target
project.windowOptions.width = 1280;
project.windowOptions.height = 720;

resolve(project);