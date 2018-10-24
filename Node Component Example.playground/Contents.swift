
import SpriteKit
import GameplayKit
import PlaygroundSupport

class PhysicsComponent : GKComponent {
	var body : SKPhysicsBody?
	var position : CGPoint?
	// 1.
	init( body : SKPhysicsBody ) {
		self.body = body
		super.init()
	}
	required init?(coder aDecoder: NSCoder) {
		fatalError("Not implemented")
	}
	// 2.
	override func didAddToEntity() {
		self.entity?.component(ofType: NodeComponent.self)?.node.physicsBody = self.body
	}
	// 3.
	override func willRemoveFromEntity() {
		if let hasNode = self.entity?.component(ofType: NodeComponent.self)?.node {
			hasNode.physicsBody = nil
			self.entity?.component(ofType: PositionComponent.self)?.currentPosition = hasNode.position
		}
		self.body = nil
	}
}

class NodeComponent : GKComponent {
	let node = TouchyNode()
	override func didAddToEntity() {
		// 1.
		self.node.entity = self.entity
		// 2.
		self.node.isUserInteractionEnabled = true
	}
	override func willRemoveFromEntity() {
		self.node.entity = nil
	}
}
class PositionComponent : GKComponent {
    var currentPosition : CGPoint
    init(pos : CGPoint){
        self.currentPosition = pos
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }

	override func didAddToEntity() {
		self.entity?.component(ofType: NodeComponent.self)?.node.position = self.currentPosition
	}
}

class ScaleComponent : GKComponent {
    // 1.
    var scaleAmountPerSecond : CGFloat = 3
    // 2.
    var targetScale : CGFloat = 1 {
        didSet {
            // 3.
            guard let hasNode = self.entity?.component(ofType: NodeComponent.self)?.node else {
                return
            }
            // 4.
            let distance = abs(targetScale - hasNode.xScale)
            let duration = TimeInterval(distance / scaleAmountPerSecond)
            // 5. 
            hasNode.removeAction(forKey: "scaleAction")
            let action = SKAction.scale(to: targetScale, duration: duration)
            hasNode.run(action, withKey: "scaleAction")
        }
    }
}

extension NodeComponent {
    // 2.
    override func update(deltaTime seconds: TimeInterval) {
        // 1.
		if let physicsComponent = self.entity?.component(ofType: PhysicsComponent.self)  {
			// 2.
			guard let hasPhysicsPosition = physicsComponent.position else {
				return
			}

			// 3.
			let distance = CGVector(dx: hasPhysicsPosition.x - self.node.position.x, dy: hasPhysicsPosition.y - self.node.position.y)
			let velocity = CGVector(dx: distance.dx / CGFloat(seconds), dy: distance.dy / CGFloat(seconds))
			
			// 4.
			physicsComponent.body?.velocity = velocity
		
		} else {
			if let hasPos = self.entity?.component(ofType: PositionComponent.self)?.currentPosition {
				self.node.position = hasPos
			}
		}
    }
}
protocol ChildNode {
    func asNode() -> SKNode
}
enum Shape {
    case circle, square
}
class ShapeComponent : GKComponent, ChildNode {
    let shape : SKShapeNode
    // 2.
    init( shape : Shape) {
        switch shape {
        case .circle:
            self.shape = SKShapeNode(circleOfRadius: 20)
        case .square:
            self.shape = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 20, height: 20))
        }
        // 3.
        self.shape.fillColor = SKColor.purple
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    func asNode() -> SKNode {
        return self.shape
    }
}

class LabelComponent : GKComponent, ChildNode {
    
    let label : SKLabelNode
    init(text: String) {
        self.label = SKLabelNode(text: text)
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    func asNode() -> SKNode {
        return self.label
    }
}

class SpriteComponent : GKComponent, ChildNode {
    let sprite : SKSpriteNode
    override init() {
        sprite = SKSpriteNode(color: #colorLiteral(red: 0.854901969432831, green: 0.250980406999588, blue: 0.47843137383461, alpha: 1.0), size: CGSize(width: 100, height: 100))
        super.init()
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
    func asNode() -> SKNode {
        return self.sprite
    }
}

enum NodeType {
    case shape, label, sprite
    static func allTypes() -> [NodeType] {
        return [.shape, .label, sprite]
    }
}

class GameScene : SKScene {
    var entities : [GKEntity] = []
    var previousTime : TimeInterval = 0
    var nodeTypes = [NodeType]()
    
    lazy var systems : [GKComponentSystem] = {
        let render = GKComponentSystem(componentClass: NodeComponent.self)
        return [render]
    }()
    override func update(_ currentTime: TimeInterval) {
        if self.previousTime == 0 {
            self.previousTime = currentTime
        }
        let delta = currentTime - self.previousTime
        
        for system in systems {
            system.update(deltaTime: delta)
        }
		self.previousTime = currentTime
		
		// BONUS: If there are ten entities, let's completely stop the physics
		// by removing the component.
		if self.entities.count == 10 {
			for entity in entities {
				entity.removeComponent(ofType: PhysicsComponent.self)
			}
		}
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 1.
        guard let touch = touches.first else {
            return
        }
        
        self.entities.last?.component(ofType: ScaleComponent.self)?.targetScale = 1
        
        // 2. 
        let loc = touch.location(in: self)
        // 3.
        self.addNode(at:loc)
    }
    
    func addNode(at point:CGPoint){
		self.physicsWorld.gravity = .zero
        let entity = GKEntity()
        let nodeComponent = NodeComponent()
        
        if nodeTypes.isEmpty {
            nodeTypes = NodeType.allTypes()
        }
        let type = nodeTypes.popLast()!
        let typeComponent : GKComponent
        switch type {
        case .shape:
            typeComponent = ShapeComponent(shape: .circle)
            case .label:
            typeComponent = LabelComponent(text: "Hello!")
            case .sprite:
            typeComponent = SpriteComponent()
        }
        if let typeComponent = typeComponent as? ChildNode {
            nodeComponent.node.addChild(typeComponent.asNode())
        }
        let positionComponent = PositionComponent(pos: point)
        let scaleComp = ScaleComponent()
         entity.addComponent(scaleComp)
        entity.addComponent(nodeComponent)
        entity.addComponent(positionComponent)
        scaleComp.targetScale = 1.5

if type != .label {
		let body = SKPhysicsBody(rectangleOf: nodeComponent.node.calculateAccumulatedFrame().size)
		let physics = PhysicsComponent(body: body)
entity.addComponent(physics)
}
		
        self.entities.append(entity)
        self.addChild(nodeComponent.node)
        for system in systems {
            system.addComponent(foundIn: entity)
        }
    }

override func didSimulatePhysics() {
	guard let hasEntity = self.entities.first else {
		return
	}
//	print("---PHYSICS APPLIED---")
//	print( hasEntity.component(ofType: PositionComponent.self)?.currentPosition ?? "No position")
//	print( hasEntity.component(ofType: NodeComponent.self)?.node.position ?? "No node")
//	print( hasEntity.component(ofType: PhysicsComponent.self)?.body?.velocity ??  "No velocity")
}
}

class TouchyNode : SKNode {
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		// 1.
		guard let t = touches.first, let scene = self.scene else {
			return
		}
		// 2.
		self.entity?.component(ofType: PhysicsComponent.self)?.position = t.location(in: scene)
		self.entity?.component(ofType: PositionComponent.self)?.currentPosition = t.location(in: scene)
	}
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let t = touches.first, let scene = self.scene  else {
			return
		}
		self.entity?.component(ofType: PositionComponent.self)?.currentPosition = t.location(in: scene)
		// 3.
		if self.entity?.component(ofType: PhysicsComponent.self)?.position == nil {
			return
		}
		self.entity?.component(ofType: PhysicsComponent.self)?.position = t.location(in: scene)
		
		
	}
	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let t = touches.first, let scene = self.scene  else {
			return
		}
		// 4.
		self.entity?.component(ofType: PhysicsComponent.self)?.position = nil
		self.entity?.component(ofType: PositionComponent.self)?.currentPosition = t.location(in: scene)
	}
}

let view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 500))
let scene = GameScene(size: view.frame.size)
scene.scaleMode = .aspectFit
view.presentScene(scene)
PlaygroundPage.current.liveView = view
