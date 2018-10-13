
import SpriteKit
import GameplayKit
import PlaygroundSupport

class NodeComponent : GKComponent {
    let node = SKNode()
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
        // 3.
        if let hasPos = self.entity?.component(ofType: PositionComponent.self)?.currentPosition {
            self.node.position = hasPos
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
        // 1.
        let entity = GKEntity()
        // 2.
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
        // 4.
        let positionComponent = PositionComponent(pos: point)
        let scaleComp = ScaleComponent()
         entity.addComponent(scaleComp)
        // 5.
        entity.addComponent(nodeComponent)
        entity.addComponent(positionComponent)
        // 6.
        scaleComp.targetScale = 1.5
        self.entities.append(entity)
        // 7.
        self.addChild(nodeComponent.node)
        // 8.
        for system in systems {
            system.addComponent(foundIn: entity)
        }
    }
}

let view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 500))
let scene = GameScene(size: view.frame.size)
scene.scaleMode = .aspectFit
view.presentScene(scene)
PlaygroundPage.current.liveView = view
