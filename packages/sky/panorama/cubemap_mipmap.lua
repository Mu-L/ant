local ecs = ...
local world = ecs.world
local w = world.w

local bgfx = require "bgfx"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local sampler = renderpkg.sampler
local viewidmgr = renderpkg.viewidmgr

local icompute = ecs.import.interface "ant.render|icompute"
local iexposure = ecs.import.interface "ant.camera|iexposure"

local thread_group_size<const> = 8

local imaterial = ecs.import.interface "ant.asset|imaterial"

local cubemap_mipmap_sys = ecs.system "cubemap_mipmap_system"

local icubemap_mipmap = ecs.interface "icubemap_mipmap"

local pcm_id = viewidmgr.get "panorama2cubmapMips"

local cubemap_textures = {
    value = nil,
    size = 0,
    mipmap_count = 0,
}

local cubemap_flags<const> = sampler {
    MIN="LINEAR",
    MAG="LINEAR",
    MIP="LINEAR",
    U="CLAMP",
    V="CLAMP",
    W="CLAMP",
    BLIT="BLIT_COMPUTEWRITE",
}

local function build_cubemap_textures(facesize, cm_rbhandle)
    cubemap_textures.value = cm_rbhandle
    cubemap_textures.size  = facesize
    cubemap_textures.mipmap_count = math.log(facesize, 2) + 1
end

local function create_cubemap_entities()
    local size = cubemap_textures.size

    local mipmap_count = cubemap_textures.mipmap_count

    local function create_cubemap_compute_entity(dispatchsize, cubemap_mipmap)
        ecs.create_entity {
            policy = {
                "ant.render|compute_policy",
                "ant.general|name",
            },
            data = {
                name        = "cubemap_mipmap_builder",
                material    = "/pkg/ant.resources/materials/postprocess/gen_cubemap_mipmap.material",
                dispatch    ={
                    size    = dispatchsize,
                },
                cubemap_mipmap = cubemap_mipmap,
                compute     = true,
                cubemap_mipmap_builder      = true,
            }
        }
    end


    for i=1, mipmap_count - 1 do
        local s = size >> (i-1)
        local dispatchsize = {
            math.floor(s / thread_group_size), math.floor(s / thread_group_size), 6
        }
        local cubemap_mipmap = {
            mipidx = i-1,
        }
        create_cubemap_compute_entity(dispatchsize, cubemap_mipmap)

    end
end

function cubemap_mipmap_sys:render_preprocess()
    for e in w:select "cubemap_mipmap_builder dispatch:in cubemap_mipmap:in" do
        local dis = e.dispatch
        local material = dis.material
        local cubemap_mipmap = e.cubemap_mipmap
        material.u_build_cubemap_mipmap_param = math3d.vector(cubemap_mipmap.mipidx, 0, 0, 0)
        material.s_source = cubemap_textures.value
        material.s_result = icompute.create_image_property(cubemap_textures.value, 1, cubemap_mipmap.mipidx + 1, "w")

        icompute.dispatch(pcm_id, dis)
        w:remove(e)
    end
end

function icubemap_mipmap.gen_cubemap_mipmap(facesize, cm_rbhandle)
    build_cubemap_textures(facesize, cm_rbhandle)
    create_cubemap_entities()
end