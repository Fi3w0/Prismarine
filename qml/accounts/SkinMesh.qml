import QtQuick
import QtQuick3D.Helpers

ProceduralMesh {
    required property var part
    property int textureWidth: 64
    property int textureHeight: 64
    readonly property var mesh: makeMesh()
    positions: mesh.positions
    normals: mesh.normals
    uv0s: mesh.uvs
    indexes: mesh.indices
    function makeMesh() {
        const p = part, e = p.inflate || 0;
        const x = p.w / 2 + e, y = p.h / 2 + e, z = p.d / 2 + e;
        const faces = [
            {points: [[-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z]], normal:[0,0,1], rect:[p.u+p.d,p.v+p.d,p.w,p.h]},
            {points: [[x,-y,-z],[-x,-y,-z],[-x,y,-z],[x,y,-z]], normal:[0,0,-1], rect:[p.u+2*p.d+p.w,p.v+p.d,p.w,p.h]},
            {points: [[-x,-y,-z],[-x,-y,z],[-x,y,z],[-x,y,-z]], normal:[-1,0,0], rect:[p.u,p.v+p.d,p.d,p.h]},
            {points: [[x,-y,z],[x,-y,-z],[x,y,-z],[x,y,z]], normal:[1,0,0], rect:[p.u+p.d+p.w,p.v+p.d,p.d,p.h]},
            {points: [[-x,y,z],[x,y,z],[x,y,-z],[-x,y,-z]], normal:[0,1,0], rect:[p.u+p.d,p.v,p.w,p.d]},
            {points: [[-x,-y,-z],[x,-y,-z],[x,-y,z],[-x,-y,z]], normal:[0,-1,0], rect:[p.u+p.d+p.w,p.v,p.w,p.d], flipV:true}
        ];
        const data = {positions: [], normals: [], uvs: [], indices: []};
        faces.forEach((face, f) => {
            const r = face.rect;
            const uv = [[r[0],r[1]+r[3]],[r[0]+r[2],r[1]+r[3]],[r[0]+r[2],r[1]],[r[0],r[1]]];
            face.points.forEach((v, i) => {
                data.positions.push(Qt.vector3d(v[0] * (p.mirror ? -1 : 1), v[1], v[2]));
                data.normals.push(Qt.vector3d(face.normal[0] * (p.mirror ? -1 : 1), face.normal[1], face.normal[2]));
                // Minecraft's bottom cap uses the opposite V direction to its top cap.
                const vTex = face.flipV ? 2 * r[1] + r[3] - uv[i][1] : uv[i][1];
                data.uvs.push(Qt.vector2d(uv[i][0] / textureWidth, 1 - vTex / textureHeight));
            });
            const b = f * 4;
            // Reflection reverses winding too; keep triangle faces aligned with their normals.
            if (p.mirror) data.indices.push(b,b+2,b+1,b,b+3,b+2);
            else data.indices.push(b,b+1,b+2,b,b+2,b+3);
        });
        return data;
    }
}
