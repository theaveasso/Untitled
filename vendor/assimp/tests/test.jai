#import "Basic";
#import,file "../module.jai";

main :: () {

    post_process_flags := aiPostProcessSteps.Triangulate | aiPostProcessSteps.CalcTangentSpace;
    scene := aiImportFileEx("cube.fbx", post_process_flags.(u32), null);
    defer aiFreeScene(scene);
    assert(scene != null, "importing cube.fbx failed. Ensure you are running from INSIDE the 'tests' folder.");

    meshes: []*aiMesh;
    meshes.data = scene.mMeshes;
    meshes.count = scene.mNumMeshes;
    for meshes {
        name := string.{data=it.mName.data.data, count=it.mName.length};
        print("mesh:\n  name=%\n  vertices=%\n  normals=%\n", name, it.mNumVertices, it.mNumVertices);
    }
}
