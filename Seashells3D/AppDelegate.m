//
//  AppDelegate.m
//  Seashells3D
//

#import "AppDelegate.h"

#import "Accelerate/Accelerate.h"

@implementation AppDelegate

typedef struct {
	float x, y, z;
	float nx, ny, nz;
} Vertex;

#define SUBDIVISIONS 250
#define COMPONENTS 3

bool clicked = false;

SCNGeometry *CreateLineSeg(SCNVector3 v1, SCNVector3 v2)
{
    // http://stackoverflow.com/questions/21886224/drawing-a-line-between-two-points-using-scenekit
    
    float globalScale = 400;
    SCNVector3 globalOffset = SCNVector3Make(-5,-33,65);

    v1.x = (v1.x * globalScale) + globalOffset.x;
    v1.y = (v1.y * globalScale) + globalOffset.y;
    v1.z = (v1.z * globalScale) + globalOffset.z;
    
    v2.x = (v2.x * globalScale) + globalOffset.x;
    v2.y = (v2.y * globalScale) + globalOffset.y;
    v2.z = (v2.z * globalScale) + globalOffset.z;
    
    SCNVector3 positions[] = { v1, v2 };
    
    int indices[] = { 0, 1 };
    
    SCNGeometrySource *vertexSource = [SCNGeometrySource geometrySourceWithVertices:positions count:2];
    
    NSData *indexData = [NSData dataWithBytes:indices length:sizeof(indices)];
    
    SCNGeometryElement *element = [
                                   SCNGeometryElement
                                   geometryElementWithData:indexData
                                   primitiveType:SCNGeometryPrimitiveTypeLine
                                   primitiveCount:1
                                   bytesPerIndex:sizeof(int)
                                   ];
    
    SCNGeometry *line = [SCNGeometry geometryWithSources:@[vertexSource] elements:@[element]];
    
    return line;
}

SCNNode *CreateLineSegNode(SCNGeometry *line)
{
    SCNNode *lineNode = [SCNNode nodeWithGeometry:line];
    
    return lineNode;
}

SCNNode *CreateLine(SCNVector3 positions[])
{
    SCNNode *parentNode = [SCNNode node];
    for (int i=1; i<sizeof(positions); i++) {
        [parentNode addChildNode:CreateLineSegNode(CreateLineSeg(positions[i-1], positions[i]))];
    }
    return parentNode;
}

SCNGeometry *CreateSeashell()
{
	// Allocate enough space for our vertices
	const NSInteger vertexCount = (SUBDIVISIONS + 1) * (SUBDIVISIONS + 1);
	Vertex *const vertices = malloc(sizeof(Vertex) * vertexCount);

	// Calculate the uv step interval given the number of subdivisions
	const float uStep = 2.0f * M_PI / SUBDIVISIONS; // (2pi - 0) / subdivisions
	const float vStep = 4.0f * M_PI / SUBDIVISIONS; // (2pi - -2pi) / subdivisions

	Vertex *currentVertex = vertices;
	float u = 0;

	// Loop through our uv-space, generating 3D vertices.
	for (NSInteger i = 0; i <= SUBDIVISIONS; i++, u += uStep) {
		float v = -2 * M_PI;

		for (NSInteger j = 0; j <= SUBDIVISIONS; j++, v += vStep, currentVertex++) {
			// Vertex calculations.
			currentVertex->x = 5/4.0f * (1-v/(2*M_PI)) * cos(2*v) * (1 + cos(u)) + cos(2*v);
			currentVertex->y = 5/4.0f * (1-v/(2*M_PI)) * sin(2*v) * (1 + cos(u)) + sin(2*v);
			currentVertex->z = 5*v / M_PI + 5/4.0f * (1 - v/(2*M_PI)) * sin(u) + 15;

			// Normal calculations.
			currentVertex->nx = (-5*(2*M_PI - v)*(2*(20 + 18*M_PI - 5*v)*cos(u - 2*v) + 5*(2*M_PI - v)*cos(2*(u - v)) + 20*M_PI*cos(2*v) - 10*v*cos(2*v) + 10*M_PI*cos(2*(u + v)) - 5*v*cos(2*(u + v)) - 40*cos(u + 2*v) + 36*M_PI*cos(u + 2*v) - 10*v*cos(u + 2*v) + 5*sin(u - 2*v) - 10*sin(2*v) - 5*sin(u + 2*v)))/(128*pow(M_PI,2));

			currentVertex->ny = (-5*(2*M_PI - v)*(5*pow(cos(v),2)*(1 + cos(u) - 8*sin(u)) - 5*sin(v)*(4*v*pow(cos(u),2)*cos(v) + (1 + cos(u) - 8*sin(u))*sin(v)) + 2*cos(u)*(18*M_PI - 5*v + 10*M_PI*cos(u))*sin(2*v)))/(64*pow(M_PI,2));

			currentVertex->nz = (-5*(2*M_PI - v)*(18*M_PI - 5*v + 5*(2*M_PI - v)*cos(u))*sin(u))/(32*pow(M_PI,2));

			// Normalize the results.
			float dot = 0;
			vDSP_dotpr(&currentVertex->nx, 1, &currentVertex->nx, 1, &dot, COMPONENTS);

			currentVertex->nx /= sqrtf(dot);
			currentVertex->ny /= sqrtf(dot);
			currentVertex->nz /= sqrtf(dot);
		}
	}

	const NSInteger indexCount = (SUBDIVISIONS * SUBDIVISIONS) * COMPONENTS * 2;
	unsigned short *const indices = malloc(sizeof(unsigned short) * indexCount);

	// Generate indices.
	unsigned short *idx = indices;
	unsigned short stripStart = 0;

	for (NSInteger i = 0; i < SUBDIVISIONS; i++, stripStart += (SUBDIVISIONS + 1)) {
		for (NSInteger j = 0; j < SUBDIVISIONS; j++) {
			unsigned short v1 = stripStart + j;
			unsigned short v2 = stripStart + j + 1;
			unsigned short v3 = stripStart + (SUBDIVISIONS+1) + j;
			unsigned short v4 = stripStart + (SUBDIVISIONS+1) + j + 1;

			*idx++ = v4;
			*idx++ = v2;
			*idx++ = v3;
			*idx++ = v1;
			*idx++ = v3;
			*idx++ = v2;
		}
	}

	NSData *data = [NSData dataWithBytes:vertices length:vertexCount * sizeof(Vertex)];
	free(vertices);

	SCNGeometrySource *source = [SCNGeometrySource geometrySourceWithData:data
																 semantic:SCNGeometrySourceSemanticVertex
															  vectorCount:vertexCount
														  floatComponents:YES
													  componentsPerVector:COMPONENTS
														bytesPerComponent:sizeof(float)
															   dataOffset:0
															   dataStride:sizeof(Vertex)];

	SCNGeometrySource *normalSource = [SCNGeometrySource geometrySourceWithData:data
																	   semantic:SCNGeometrySourceSemanticNormal
																	vectorCount:vertexCount
																floatComponents:YES
															componentsPerVector:COMPONENTS
															  bytesPerComponent:sizeof(float)
																	 dataOffset:offsetof(Vertex, nx)
																	 dataStride:sizeof(Vertex)];

	SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:indices length:indexCount * sizeof(unsigned short)]
																primitiveType:SCNGeometryPrimitiveTypeTriangles
															   primitiveCount:indexCount/COMPONENTS
																bytesPerIndex:sizeof(unsigned short)];

	free(indices);

	return [SCNGeometry geometryWithSources:@[source, normalSource] elements:@[element]];
}

- (void) mouseDown: (NSEvent*) theEvent;
{
    clicked = true;
}

- (void) mouseUp: (NSEvent*) theEvent;
{
    clicked = false;
}

SCNScene *scene;
SCNNode *cameraNode;
SCNLight *spotLight;
SCNNode *spotLightNode;
NSTimer *timer;

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
	// Set up the scene.
    scene = [SCNScene scene];
    self.sceneView.scene = scene;

	// 1. Camera
	cameraNode = [SCNNode node];
	cameraNode.camera = [SCNCamera camera];
	cameraNode.position = SCNVector3Make(4, 4, 30);
	cameraNode.transform = CATransform3DRotate(cameraNode.transform, -M_PI/14, -1, 0, 0);
	[scene.rootNode addChildNode:cameraNode];

	// 2. Spot light
	spotLight = [SCNLight light];
	spotLight.type = SCNLightTypeOmni;
	spotLight.color = [NSColor whiteColor];

	spotLightNode = [SCNNode node];
	spotLightNode.light = spotLight;
	spotLightNode.position = SCNVector3Make(-2, 1, 0);
	[cameraNode addChildNode:spotLightNode];

	// 3. Seashell
    /*
    SCNGeometry *seashellGeometry = CreateSeashell();
	seashellGeometry.firstMaterial = [SCNMaterial material];
	seashellGeometry.firstMaterial.diffuse.contents = [NSColor redColor];
	seashellGeometry.firstMaterial.doubleSided = YES;
    
	CGFloat radius = 0;
	[seashellGeometry getBoundingSphereCenter:nil radius:&radius];

	SCNNode *parent = [SCNNode node];
	parent.position = SCNVector3Make(0, radius/2, 0);

	SCNNode *seashellGeometryNode = [SCNNode nodeWithGeometry:seashellGeometry];
	seashellGeometryNode.pivot = CATransform3DMakeTranslation(0, 0, radius);
	seashellGeometryNode.rotation = SCNVector4Make(4, -2, 0, -M_PI_4);
	[parent addChildNode:seashellGeometryNode];

	[scene.rootNode addChildNode:parent];
    */
    
    // ~ ~ ~ ~ ~ ~ ~
    SCNVector3 positions[] = {
        SCNVector3Make(0.02122315, 0.09764352, -0.09464524),
        SCNVector3Make(0.02127743, 0.09723012, -0.09445883),
        SCNVector3Make(0.02125985, 0.09669, -0.09432771),
        SCNVector3Make(0.02141782, 0.09605183, -0.09417694),
        SCNVector3Make(0.02158549, 0.09543362, -0.09400591),
        SCNVector3Make(0.02185604, 0.09462197, -0.09380004),
        SCNVector3Make(0.02219184, 0.09371823, -0.0935743),
        SCNVector3Make(0.02270248, 0.09278156, -0.09320874),
        SCNVector3Make(0.02315176, 0.0920057, -0.09295152),
        SCNVector3Make(0.02368221, 0.09129754, -0.09267108),
        SCNVector3Make(0.02413617, 0.09077168, -0.09250132),
        SCNVector3Make(0.02466266, 0.09035334, -0.09226093),
        SCNVector3Make(0.02510297, 0.08982813, -0.0920922),
        SCNVector3Make(0.02547988, 0.08939639, -0.09201562),
        SCNVector3Make(0.02597008, 0.08894365, -0.09182418),
        SCNVector3Make(0.02628547, 0.08849977, -0.09173421),
        SCNVector3Make(0.02658181, 0.08806379, -0.09171825),
        SCNVector3Make(0.02683281, 0.08769009, -0.09170464),
        SCNVector3Make(0.02703543, 0.08729474, -0.0917352),
        SCNVector3Make(0.02717705, 0.0869197, -0.09182739),
        SCNVector3Make(0.02730196, 0.08663502, -0.09194939),
        SCNVector3Make(0.02736504, 0.08638257, -0.09211324),
        SCNVector3Make(0.02745271, 0.08611909, -0.09226385),
        SCNVector3Make(0.02744476, 0.08595106, -0.09250295),
        SCNVector3Make(0.02742184, 0.08576694, -0.09273823),
        SCNVector3Make(0.02730051, 0.08565874, -0.09310246),
        SCNVector3Make(0.02720973, 0.08555326, -0.09349009),
        SCNVector3Make(0.02707554, 0.0854561, -0.09387723),
        SCNVector3Make(0.02691317, 0.08538923, -0.09434193),
        SCNVector3Make(0.02665302, 0.08535442, -0.09503536),
        SCNVector3Make(0.02637439, 0.08525302, -0.09570462),
        SCNVector3Make(0.02613228, 0.08516808, -0.09643336),
        SCNVector3Make(0.02585012, 0.08499959, -0.09724806),
        SCNVector3Make(0.02551212, 0.08482811, -0.09820897),
        SCNVector3Make(0.0252078, 0.084684, -0.09911948),
        SCNVector3Make(0.02481922, 0.08453418, -0.1001543),
        SCNVector3Make(0.02443841, 0.08441368, -0.101155),
        SCNVector3Make(0.02400327, 0.08436954, -0.1022772),
        SCNVector3Make(0.02354093, 0.08439711, -0.10339),
        SCNVector3Make(0.02303329, 0.08448614, -0.1045159),
        SCNVector3Make(0.02251147, 0.08470705, -0.1056912),
        SCNVector3Make(0.02208112, 0.0849254, -0.1067405),
        SCNVector3Make(0.02161157, 0.08524528, -0.1077978),
        SCNVector3Make(0.02127125, 0.08549929, -0.1087025),
        SCNVector3Make(0.02099891, 0.08573829, -0.1094349),
        SCNVector3Make(0.02073649, 0.08590323, -0.1100097),
        SCNVector3Make(0.02055052, 0.08602451, -0.1104224),
        SCNVector3Make(0.02035827, 0.08617458, -0.1108241),
        SCNVector3Make(0.02024353, 0.08627146, -0.1109344),
        SCNVector3Make(0.02006079, 0.08651899, -0.1110243),
        SCNVector3Make(0.01985455, 0.08689818, -0.1110535),
        SCNVector3Make(0.01963564, 0.08741702, -0.111042),
        SCNVector3Make(0.01938166, 0.08794975, -0.1110444),
        SCNVector3Make(0.0191191, 0.08873807, -0.1109797),
        SCNVector3Make(0.01883033, 0.08954918, -0.1110145),
        SCNVector3Make(0.0185247, 0.09042487, -0.1111081),
        SCNVector3Make(0.01828514, 0.09127669, -0.1111537),
        SCNVector3Make(0.0180326, 0.09200056, -0.1112598),
        SCNVector3Make(0.01775927, 0.09267572, -0.1114256),
        SCNVector3Make(0.01747414, 0.09324321, -0.1115533),
        SCNVector3Make(0.01719381, 0.09376058, -0.1116839),
        SCNVector3Make(0.01694171, 0.09427145, -0.1117574),
        SCNVector3Make(0.01661611, 0.09469192, -0.1119533),
        SCNVector3Make(0.01638919, 0.09512629, -0.1120699),
        SCNVector3Make(0.01611353, 0.09547457, -0.1122119),
        SCNVector3Make(0.01584071, 0.09571214, -0.112328),
        SCNVector3Make(0.01563662, 0.0959601, -0.1123597),
        SCNVector3Make(0.0154383, 0.09615061, -0.1122921),
        SCNVector3Make(0.01526754, 0.09630649, -0.1121564),
        SCNVector3Make(0.01516144, 0.09647638, -0.1118664),
        SCNVector3Make(0.01503809, 0.0966814, -0.1115264),
        SCNVector3Make(0.01510203, 0.0969086, -0.1108408),
        SCNVector3Make(0.01517116, 0.09712061, -0.1101607),
        SCNVector3Make(0.01524555, 0.09734491, -0.1094981),
        SCNVector3Make(0.0154684, 0.09758523, -0.1086064),
        SCNVector3Make(0.01564069, 0.09778422, -0.107769),
        SCNVector3Make(0.01593597, 0.09791279, -0.1067088),
        SCNVector3Make(0.01629189, 0.09800713, -0.1055926),
        SCNVector3Make(0.01670762, 0.09805046, -0.10446),
        SCNVector3Make(0.01714311, 0.0980923, -0.1033124),
        SCNVector3Make(0.01760369, 0.09812197, -0.1021874),
        SCNVector3Make(0.01813384, 0.09811056, -0.1011488),
        SCNVector3Make(0.0185868, 0.09805833, -0.1001173),
        SCNVector3Make(0.01899109, 0.09793384, -0.09919434),
        SCNVector3Make(0.01945176, 0.09780875, -0.09827929),
        SCNVector3Make(0.01984194, 0.09763399, -0.09746659),
        SCNVector3Make(0.02015747, 0.09743428, -0.09675737),
        SCNVector3Make(0.02044886, 0.09729289, -0.09614433),
        SCNVector3Make(0.02068699, 0.0971801, -0.09563953),
        SCNVector3Make(0.02084599, 0.09709349, -0.09523073),
        SCNVector3Make(0.02098875, 0.09706523, -0.09485715),
        SCNVector3Make(0.02110011, 0.09699954, -0.0945894),
        SCNVector3Make(0.02117761, 0.0969156, -0.09436801),
        SCNVector3Make(0.02121585, 0.09685758, -0.09418401),
        SCNVector3Make(0.02128294, 0.09676798, -0.09402537),
        SCNVector3Make(0.02134357, 0.09669967, -0.09391207),
        SCNVector3Make(0.02136743, 0.09663573, -0.09383146),
        SCNVector3Make(0.02138655, 0.09652862, -0.09385519),
        SCNVector3Make(0.02138485, 0.0964157, -0.09390293),
        SCNVector3Make(0.0213275, 0.09629436, -0.09398066),
        SCNVector3Make(0.02120915, 0.09605069, -0.09427813),
        SCNVector3Make(0.02113138, 0.09581545, -0.09450329),
        SCNVector3Make(0.02096298, 0.09547232, -0.09488805),
        SCNVector3Make(0.02072073, 0.09502459, -0.09532685)
    };
    SCNNode *lineNode = CreateLine(positions);
    [scene.rootNode addChildNode:lineNode];
    lineNode.transform = CATransform3DRotate(lineNode.transform, 0.02, 1, 0, 0);
    // ~ ~ ~ ~ ~ ~ ~
    
	// 4. Floor
	SCNFloor *floor = [SCNFloor floor];
	floor.firstMaterial.diffuse.contents = [NSColor darkGrayColor];
	floor.reflectivity = 0.2;
	floor.reflectionFalloffEnd = 8;
	[scene.rootNode addChildNode:[SCNNode nodeWithGeometry:floor]];
	
	// Set the scene.
	
	// Begin the rotation animation.
	/*
    CABasicAnimation *rotationAnimation = [CABasicAnimation animationWithKeyPath:@"rotation"];
	rotationAnimation.duration = 10;
	rotationAnimation.repeatCount = FLT_MAX;
	rotationAnimation.toValue = [NSValue valueWithSCNVector4:SCNVector4Make(0, 1, 0, M_PI*2)];
	
	[parent addAnimation:rotationAnimation forKey:nil];
    */
    
    timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(handleTimer:) userInfo:nil repeats:YES];
}

- (void) handleTimer:(NSTimer *)theTimer {
    if ([theTimer isValid]) {
        //implement your methods
        SCNVector3 pos2[] = { SCNVector3Make(0,0,0), SCNVector3Make(10,10,10), SCNVector3Make(7,7,7), SCNVector3Make(0,0,0) };
        SCNNode *lineNode2 = CreateLine(pos2);
        [scene.rootNode addChildNode:lineNode2];
    }
    
    - (void) renderer:(id<SCNSceneRenderer>) renderer {
updateAtTime:(NSTimeInterval)time;
    }
}

@end
