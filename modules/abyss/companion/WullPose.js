.pragma library
// Orthographic projection of the same centered 3D volume used by Blender.
// R = roll(Z) * yaw(Y) * pitch(X); inverse depth scale retains liquid volume.
function rotation(yaw, pitch, roll) {
    const y=yaw*Math.PI/180,p=pitch*Math.PI/180,r=roll*Math.PI/180;
    const cy=Math.cos(y),sy=Math.sin(y),cp=Math.cos(p),sp=Math.sin(p),cr=Math.cos(r),sr=Math.sin(r);
    return [cr*cy,cr*sy*sp-sr*cp,cr*sy*cp+sr*sp,
        sr*cy,sr*sy*sp+cr*cp,sr*sy*cp-cr*sp,-sy,cy*sp,cy*cp];
}
function depthScale(sx, sy) {return 1/(sx*sy);}
function project(r, x, y, z, sx=1, sy=1) {
    x*=sx;y*=sy;z*=depthScale(sx,sy);
    return {x:r[0]*x+r[1]*y+r[2]*z,y:r[3]*x+r[4]*y+r[5]*z,z:r[6]*x+r[7]*y+r[8]*z};
}
// Place a front-facing surface plane in the same spatial pose as the liquid.
function faceMatrix(r, sx, sy, cx=38, cy=46.14, depth=26) {
    const a=r[0]*sx,b=-r[1]*sy,d=-r[3]*sx,e=r[4]*sy,z=depth*depthScale(sx,sy);
    return [a,b,0,cx-a*cx-b*cy+r[2]*z,
        d,e,0,cy-d*cx-e*cy-r[5]*z,0,0,1,0,0,0,0,1];
}
if(typeof module!=="undefined")module.exports={rotation,project,depthScale,faceMatrix};
