import trimesh, numpy as np, sys, os
from trimesh.visual.material import PBRMaterial
S=sys.argv[1]; out=sys.argv[2]
m=trimesh.load(S+'/proc/scaled.ply')
m.apply_transform(trimesh.transformations.rotation_matrix(np.pi,[0,1,0]))
c=m.triangles_center; n=m.face_normals
x,y,z=np.abs(c[:,0]),c[:,1],c[:,2]
label=np.zeros(len(c),int)
R=0.37
for zc in (1.38,-1.28):
    d=np.hypot(y-R,z-zc)
    label[(d<R+0.03)&(x>0.6)]=3
glass=(y>0.8)&(z<1.62)&(z>-1.15)&(label==0)
label[glass]=1
rear=((z>1.85)&(n[:,2]>0.25)&(y<0.9))|((z>1.75)&(y<0.62))
trim=(label==0)&((y<0.24)|((z<-1.95)&(y<0.42))|rear)
label[trim]=2
adj=m.face_adjacency
for _ in range(4):
    votes=np.zeros((len(c),4))
    np.add.at(votes,(adj[:,0],label[adj[:,1]]),1)
    np.add.at(votes,(adj[:,1],label[adj[:,0]]),1)
    votes[np.arange(len(c)),label]+=1.5
    label=votes.argmax(1)
mats=[PBRMaterial(name='body',baseColorFactor=[235,236,238,255],metallicFactor=0.15,roughnessFactor=0.35),
      PBRMaterial(name='glass',baseColorFactor=[30,23,11,255],metallicFactor=0.9,roughnessFactor=0.08),
      PBRMaterial(name='trim',baseColorFactor=[22,22,24,255],metallicFactor=0.3,roughnessFactor=0.5),
      PBRMaterial(name='tyre',baseColorFactor=[14,14,14,255],metallicFactor=0.0,roughnessFactor=0.85)]
scene=trimesh.Scene()
for i,mat in enumerate(mats):
    sub=m.submesh([np.where(label==i)[0]],append=True)
    sub.visual=trimesh.visual.TextureVisuals(material=mat)
    scene.add_geometry(sub,node_name=mat.name,geom_name=mat.name)
scene.export(out); print(os.path.getsize(out))
