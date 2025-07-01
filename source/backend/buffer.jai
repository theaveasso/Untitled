cbuffer_create :: (gfx_device: *Graphics_Device, 
                   buffer: **ID3D11Buffer, bind_flags: D3D11_BIND_FLAG, size: u32, data: *void = null) -> bool {

    cbd : D3D11_BUFFER_DESC;
    cbd.Usage = .DYNAMIC;
    cbd.BindFlags = bind_flags;
    cbd.CPUAccessFlags = .WRITE;
    cbd.ByteWidth = size;

    if data != null {
        id : D3D11_SUBRESOURCE_DATA;
        id.pSysMem = data;
        hr := HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, *id, buffer));
        return SUCCEEDED(hr);
    } else {
        hr := HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, buffer));
        return SUCCEEDED(hr);
    }
}

sbuffer_create :: (gfx_device: *Graphics_Device,
                   buffer: **ID3D11Buffer, size: u32, structure_byte_stride: u32, data: *void = null) -> bool {

    cbd : D3D11_BUFFER_DESC;
    cbd.Usage = .DEFAULT;
    cbd.CPUAccessFlags = .WRITE;
    cbd.ByteWidth = size;
    cbd.BindFlags = .SHADER_RESOURCE;
    cbd.MiscFlags = .BUFFER_STRUCTURED;
    cbd.StructureByteStride = structure_byte_stride;

    if data != null {
        id : D3D11_SUBRESOURCE_DATA;
        id.pSysMem = data;
        hr := HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, *id, buffer));
        return SUCCEEDED(hr);
    } else {
        hr := HR(ID3D11Device_CreateBuffer(gfx_device.d3d_device, *cbd, null, buffer));
        return SUCCEEDED(hr);
    }
}

cbuffer_map :: (using gfx_device: *Graphics_Device,
                   buffer: *ID3D11Buffer, data: *void, size: u32) {

    mapped_data : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, buffer, 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, data, size);
    ID3D11DeviceContext_Unmap(d3d_context, buffer, 0);
}
