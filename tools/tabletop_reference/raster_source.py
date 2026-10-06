"""Rasterize explicitly selected GLB surfaces through their material UVs."""
import argparse
import json
from pathlib import Path
import numpy as np
from PIL import Image
from glb_source import Source


def raster(source, names, origin, spacing, shape, height_range=None):
    rgb = np.zeros((*shape,3),np.uint8)
    heights = np.full(shape,np.nan,np.float32)
    surface_ids = np.full(shape,-1,np.int16)
    for si,p in enumerate(source.primitives):
        if p['name'] not in names:
            continue
        tex,info,sampler = source.texture(p)
        uv = p['uv'].copy()
        ext = info.get('extensions',{}).get('KHR_texture_transform',{})
        angle = ext.get('rotation',0.)
        uv *= ext.get('scale',[1,1])
        uv = uv @ np.array([[np.cos(angle),np.sin(angle)],[-np.sin(angle),np.cos(angle)]])
        uv += ext.get('offset',[0,0])
        for ids in p['indices']:
            vertices = p['vertices'][ids]
            xy = (vertices[:,[0,2]]-origin)/spacing
            mat = np.stack([xy[1]-xy[0],xy[2]-xy[0]],axis=1)
            if abs(np.linalg.det(mat)) < 1e-7:
                continue
            low = np.maximum(np.floor(xy.min(0)).astype(int),0)
            high = np.minimum(np.ceil(xy.max(0)).astype(int)+1,shape[::-1])
            if np.any(high<=low):
                continue
            yy,xx = np.mgrid[low[1]:high[1],low[0]:high[0]]
            b = (np.stack([xx,yy],-1)-xy[0]) @ np.linalg.inv(mat).T
            weights = np.concatenate([1-b.sum(-1,keepdims=True),b],axis=-1)
            h = weights @ vertices[:,1]
            mask = (weights.min(-1)>=-1e-6) & (np.isnan(heights[yy,xx]) | (h>=heights[yy,xx]))
            if height_range is not None:
                mask &= (h>=height_range[0]) & (h<=height_range[1])
            tc = weights @ uv[ids]
            for axis,wrap in enumerate([sampler.get('wrapS',10497),sampler.get('wrapT',10497)]):
                if wrap == 10497:
                    tc[...,axis] %= 1.
                elif wrap == 33648:
                    tc[...,axis] = 1.-abs(tc[...,axis]%2.-1.)
                else:
                    assert wrap == 33071
                    tc[...,axis] = np.clip(tc[...,axis],0.,1.)
            tx = np.clip((tc[...,0]*tex.shape[1]).astype(int),0,tex.shape[1]-1)
            ty = np.clip((tc[...,1]*tex.shape[0]).astype(int),0,tex.shape[0]-1)
            rgb[yy[mask],xx[mask]] = tex[ty[mask],tx[mask]]
            heights[yy[mask],xx[mask]] = h[mask]
            surface_ids[yy[mask],xx[mask]] = si
    return dict(rgb=rgb,heights=heights,surface_ids=surface_ids,origin=origin,spacing=spacing)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('profile')
    args = parser.parse_args()
    profile = json.loads(Path(args.profile).read_text())
    source = Source(profile['source'],profile['scale'],profile['offset'])
    out = Path(profile['output'])
    out.mkdir(parents=True,exist_ok=True)
    for name,layer in profile['maps'].items():
        data = raster(source,layer['surfaces'],np.array(profile['origin']),profile['spacing'],tuple(profile['shape']),layer.get('height_range'))
        np.savez_compressed(out/f'{name}.npz',**data)
        Image.fromarray(data['rgb']).save(out/f'{name}.png')
        print(name,int(np.isfinite(data['heights']).sum()))
