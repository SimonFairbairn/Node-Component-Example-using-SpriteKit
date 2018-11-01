
import SpriteKit
import GameplayKit
import PlaygroundSupport

// COMPONENTS
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

class ContactComponent : GKComponent {
	// 1.
	var targetEntities : [GKEntity] = []
	// 2.
	func didMakeContact( with entity : GKEntity? ) {
		guard let entity = entity else {
			return
		}
		self.targetEntities.append(entity)
	}
}

protocol ChildNode {
	func asNode() -> SKNode
}
enum Shape {
	case circle, square, floor
}
class ShapeComponent : GKComponent, ChildNode {
	let shape : SKShapeNode
	init( shape : Shape) {
		switch shape {
		case .circle:
			self.shape = SKShapeNode(circleOfRadius: 20)
			self.shape.fillColor = SKColor.purple
		case .square:
			self.shape = SKShapeNode(rectOf: CGSize(width: 50, height: 50))
			self.shape.fillColor = SKColor.red
		case .floor:
			self.shape = SKShapeNode(rectOf: CGSize(width: 800, height: 20))
			self.shape.fillColor = SKColor.orange
		}
		
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

// SYSTEMS
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

extension ContactComponent {
	override func update(deltaTime seconds: TimeInterval) {
		// 1.
		for entity in targetEntities {
			guard let body = entity.component(ofType: PhysicsComponent.self)?.body else {
				continue
			}
			if body.categoryBitMask == PhysicsCategory.circle {
				entity.component(ofType: 	NodeComponent.self)?.node.removeFromParent()
			} else {
				body.applyImpulse(CGVector(dx:10, dy: 25))
			}
		}
		// 2.
		targetEntities.removeAll()
	}
}

enum NodeType : CaseIterable {
    case circle, square, label, sprite, floor
}

struct PhysicsCategory  {
	static let none : UInt32 = 0b1
	static let circle : UInt32 = 0b1
	static let floor : UInt32 = 0b100
	static let square : UInt32 = 0b1000
}

class GameScene : SKScene {
    var entities : [GKEntity] = []
    var previousTime : TimeInterval = 0
    var nodeTypes = [NodeType]()
    
lazy var systems : [GKComponentSystem] = {
	let contact = GKComponentSystem(componentClass: ContactComponent.self)
	let render = GKComponentSystem(componentClass: NodeComponent.self)
	return [contact, render]
}()
	
	override func didMove(to view: SKView) {
		self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		self.addNode(.floor, at: CGPoint(x: 0, y: -(self.size.height / 2)))
		self.physicsWorld.contactDelegate = self
	}
	
	
    override func update(_ currentTime: TimeInterval) {
        if self.previousTime == 0 {
            self.previousTime = currentTime
        }
        let delta = currentTime - self.previousTime
        
        for system in systems {
            system.update(deltaTime: delta)
        }
		self.previousTime = currentTime
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // 1.
        guard let touch = touches.first else {
            return
        }
        
        self.entities.last?.component(ofType: ScaleComponent.self)?.targetScale = 1
        
        // 2. 
        let loc = touch.location(in: self)
		if loc.y > 0 {
			self.addNode(.circle, at:loc)
		} else {
			self.addNode(.square, at:loc)
		}
		
    }
    
	func addNode(_ type : NodeType, at point:CGPoint){
		
		let entity = GKEntity()
		let nodeComponent = NodeComponent()
		let typeComponent : GKComponent
		let body: SKPhysicsBody?
		switch type {
		case .floor:
			typeComponent = ShapeComponent(shape: .floor)
			body = SKPhysicsBody(rectangleOf: CGSize(width: 800, height: 20))
			body?.isDynamic = false
			body?.categoryBitMask = PhysicsCategory.floor
			body?.contactTestBitMask = PhysicsCategory.circle | PhysicsCategory.square
			
			let contactComponent = ContactComponent()
			entity.addComponent(contactComponent)
		case .circle:
			typeComponent = ShapeComponent(shape: .circle)
			body = SKPhysicsBody(circleOfRadius: 20)
			body?.categoryBitMask = PhysicsCategory.circle
		case .square:
			typeComponent = ShapeComponent(shape: .square)
			body = SKPhysicsBody(rectangleOf: CGSize(width: 50, height: 50))
			body?.categoryBitMask = PhysicsCategory.square
		case .label:
			typeComponent = LabelComponent(text: "Hello!")
			body = nil
		case .sprite:
			typeComponent = SpriteComponent()
			body = SKPhysicsBody(rectangleOf: CGSize(width: 100, height: 100))
		}
		if let typeComponent = typeComponent as? ChildNode {
			nodeComponent.node.addChild(typeComponent.asNode())
		}
		let positionComponent = PositionComponent(pos: point)
		let scaleComp = ScaleComponent()
		entity.addComponent(scaleComp)
		entity.addComponent(nodeComponent)
		entity.addComponent(positionComponent)
		
		
		if let hasBody = body {
			let physics = PhysicsComponent(body: hasBody)
			entity.addComponent(physics)
		}
		
		self.entities.append(entity)
		self.addChild(nodeComponent.node)
		for system in systems {
			system.addComponent(foundIn: entity)
		}
	}
}

extension GameScene : SKPhysicsContactDelegate {
	func didBegin(_ contact: SKPhysicsContact) {
		contact.bodyA.node?.entity?.component(ofType: ContactComponent.self)?.didMakeContact(with: contact.bodyB.node?.entity)
		contact.bodyB.node?.entity?.component(ofType: ContactComponent.self)?.didMakeContact(with: contact.bodyA.node?.entity)
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
view.showsFPS = true
view.showsPhysics = true
view.presentScene(scene)
PlaygroundPage.current.liveView = view
