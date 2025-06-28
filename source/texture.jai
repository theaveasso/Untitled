Texture_D3D11_Specific :: struct {
    image       : *ID3D11Texture2D;
    image_view  : *ID3D11ShaderResourceView;
}

Texture :: struct {
    width, height, depth : s32 = 1;
    mipmap_count : u32 = 1;
    array_length : u32 = 1;

    using specific : Texture_D3D11_Specific; 
}

texture_load_from_file :: (gfx_device: *Graphics_Device, using tex: *Texture, filepath: string, srgb:= false, build_mipmaps:= false) -> bool {
    bitmap : Bitmap;
    if !bitmap_load(*bitmap, filepath) {
        return false;
    }
    defer deinit(*bitmap);

    width  = bitmap.width;
    height = bitmap.height;
    depth  = 1; 

    texture_desc : D3D11_TEXTURE2D_DESC;
    texture_desc.Width          = xx width;
    texture_desc.Height         = xx height;
    texture_desc.MipLevels      = 0;
    texture_desc.ArraySize      = 1;
    texture_desc.Format         = .R8G8B8A8_UNORM;
    texture_desc.SampleDesc.Count  = 1;
    texture_desc.SampleDesc.Quality= 0;
    texture_desc.Usage          = .DEFAULT;
    texture_desc.BindFlags      = .SHADER_RESOURCE | .RENDER_TARGET;
    texture_desc.CPUAccessFlags = 0;
    texture_desc.MiscFlags      = .GENERATE_MIPS;

    HR(ID3D11Device_CreateTexture2D(gfx_device.d3d_device, *texture_desc, null, *tex.image));

    row_pitch := width * 4;
    ID3D11DeviceContext_UpdateSubresource(gfx_device.d3d_context, tex.image, 0, null, bitmap.data.data, xx row_pitch, 0);

    srv_desc : D3D11_SHADER_RESOURCE_VIEW_DESC;
    srv_desc.Format         = texture_desc.Format;
    srv_desc.ViewDimension  = .TEXTURE2D;
    srv_desc.Texture2D.MostDetailedMip= 0;
    srv_desc.Texture2D.MipLevels      = 1;

    HR(ID3D11Device_CreateShaderResourceView(gfx_device.d3d_device, tex.image, *srv_desc, *tex.image_view));

    ID3D11DeviceContext_GenerateMips(gfx_device.d3d_context, tex.image_view);

    return true;
}