import QtQuick
import QtQuick3D
import "SkinParts.js" as SkinParts

View3D {
    id: scene
    property string skin: ""
    property bool slim: false
    property bool legacy: false
    property bool layers: true
    // Cape texture URL; Minecraft capes are 64×32 (or a higher resolution of the same layout).
    property string cape: ""
    // Draws the cape texture as elytra wings instead of a cape.
    property bool elytra: false
    property real angle: -24
    function turn() { angle += 180; }
    camera: previewCamera
    environment: SceneEnvironment {
        backgroundMode: SceneEnvironment.Transparent
        antialiasingMode: SceneEnvironment.MSAA
        antialiasingQuality: SceneEnvironment.High
    }
    OrthographicCamera {
        id: previewCamera
        z: 100
        y: 3
        horizontalMagnification: Math.min(scene.width / 30, scene.height / 40)
        verticalMagnification: horizontalMagnification
    }
    DirectionalLight { eulerRotation: Qt.vector3d(-20, -25, 0); brightness: 1.0; ambientColor: "#888888" }
    DirectionalLight { eulerRotation: Qt.vector3d(0, 155, 0); brightness: 0.45 }
    Texture {
        id: skinTexture
        minFilter: Texture.Nearest
        magFilter: Texture.Nearest
        sourceItem: Image { width: 64; height: scene.legacy ? 32 : 64; source: scene.skin; smooth: false }
    }
    Texture {
        id: capeTexture
        minFilter: Texture.Nearest
        magFilter: Texture.Nearest
        sourceItem: Image { id: capeImage; width: 64; height: 32; source: scene.cape; smooth: false }
    }
    Node {
        eulerRotation.y: scene.angle
        Behavior on eulerRotation { enabled: !drag.pressed && Colors.animations; Vector3dAnimation { duration: 360; easing.type: Easing.OutCubic } }
        Repeater3D {
            model: SkinParts.parts(scene.slim, scene.legacy, scene.layers)
            delegate: Model {
                required property var modelData
                x: modelData.x
                y: modelData.y
                geometry: SkinMesh { part: modelData; textureHeight: scene.legacy ? 32 : 64 }
                // The outer layer blends like in game, so tinted glasses and similar stay see-through.
                readonly property bool overlay: (modelData.inflate || 0) > 0
                materials: PrincipledMaterial {
                    baseColorMap: skinTexture
                    roughness: 1
                    metalness: 0
                    alphaMode: overlay ? PrincipledMaterial.Blend : PrincipledMaterial.Mask
                    alphaCutoff: 0.1
                    cullMode: overlay ? Material.BackFaceCulling : Material.NoCulling
                    depthDrawMode: overlay ? Material.OpaquePrePassDepthDraw : Material.OpaqueOnlyDepthDraw
                }
            }
        }
        // Elytra wings use the cape texture at (22, 0), hinged at the shoulders like in game. Each wing is
        // inflated by 1 px as in Minecraft, and tilts back before it spreads (Z·X order) so the wings never share a plane.
        Repeater3D {
            model: scene.elytra && scene.cape !== "" && capeImage.status === Image.Ready ? [1, -1] : []
            delegate: Node {
                required property int modelData
                x: 5 * modelData
                y: 8
                z: -2
                eulerRotation.z: 15 * modelData
                Node {
                    eulerRotation.x: 15
                    Model {
                        x: -5 * modelData
                        y: -10
                        z: -1
                        geometry: SkinMesh { part: ({w: 10, h: 20, d: 2, u: 22, v: 0, inflate: 1, mirror: modelData < 0}); textureHeight: 32 }
                        materials: PrincipledMaterial {
                            baseColorMap: capeTexture
                            roughness: 1
                            metalness: 0
                            alphaMode: PrincipledMaterial.Mask
                            alphaCutoff: 0.1
                            // Cape atlases cut the wing silhouette out with alpha. Transparent
                            // front faces must not hide the artwork on the back of the wing.
                            depthDrawMode: Material.OpaquePrePassDepthDraw
                            cullMode: Material.NoCulling
                        }
                    }
                }
            }
        }
        // Hangs from the shoulders behind the body, tilted slightly back.
        Node {
            visible: !scene.elytra && scene.cape !== "" && capeImage.status === Image.Ready
            y: 8
            z: -2.1
            eulerRotation.x: 8
            // Turned around like the game's cloak, so the artwork at (1, 1) faces outward.
            Model {
                y: -8
                z: -0.5
                eulerRotation.y: 180
                geometry: SkinMesh { part: ({w: 10, h: 16, d: 1, u: 0, v: 0}); textureHeight: 32 }
                materials: PrincipledMaterial {
                    baseColorMap: capeTexture
                    roughness: 1
                    metalness: 0
                    alphaMode: PrincipledMaterial.Mask
                    alphaCutoff: 0.1
                    cullMode: Material.NoCulling
                }
            }
        }
    }
    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real startX
        property real startAngle
        onPressed: mouse => { startX = mouse.x; startAngle = scene.angle; }
        onPositionChanged: mouse => { if (pressed) scene.angle = startAngle + (mouse.x - startX) * 0.65; }
        onDoubleClicked: scene.angle = -24
    }
}
