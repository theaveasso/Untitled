PBindable_Tag :: enum u32 {
    Constant_Buffer :: 0;
    Vertex\_Buffer  :: 1;

    CBuffer_Transform :: 7;
}

SBindable_Tag :: enum u8 {
    Index\ _Buffer  :: 0;

    Topology        :: 1;

    Input\_Layout   :: 2;
    Vertex_Shader   :: 3;
    Pixel\_Shader   :: 4;
}

PBindable_Tag_Haver :: struct {
    tag: PBindable_Tag;
}

SBindable_Tag_Haver :: struct {
    tag: SBindable_Tag;
}

PBindable :: struct {
    tag: PBindable_Tag;
}

SBindable :: struct {
    tag: SBindable_Tag;
}

Shader_Type :: enum u8 {
    Vertex;
    Pixel;
}

Constant_Buffer :: struct ($T: Type) {
    #as using base: PBindable;
    tag = .Constant_Buffer;
    cbuffer_shader: Shader_Type;
    slot: u32;

    buffer: *ID3D11Buffer;
}

Vertex_Buffer :: struct ($T: Type) {
    #as using base: PBindable;
    tag = .Vertex_Buffer;

    buffer: *ID3D11Buffer;
}

Index_Buffer :: struct {
    #as using base: SBindable;
    tag = .Index_Buffer;

    buffer: *ID3D11Buffer;
}

Input_Layout_Desc :: struct {
    layout:   []D3D11_INPUT_ELEMENT_DESC;
    bytecode: string;
}

Input_Layout :: struct {
    #as using base: SBindable;
    tag = .Input_Layout;

    il: *ID3D11InputLayout;
}

Vertex_Shader :: struct {
    #as using base: SBindable;
    tag = .Vertex_Shader;

    shader: *ID3D11VertexShader;
    bytecode: string;
}

Pixel_Shader :: struct {
    #as using base: SBindable;
    tag = .Pixel_Shader;

    shader: *ID3D11PixelShader;
    bytecode: string;
}

pbindable_bind   :: (gfx: *Graphics_Device, resource: $T/interface PBindable_Tag_Haver) {
    #if resource.tag == {
        case .Constant_Buffer;
            cbuffer_bind(gfx, resource);
        case .Vertex_Buffer;
            vertex_buffer_bind(gfx, resource);
        case .Index_Buffer;
            index_buffer_bind(gfx, resource);
    }
}

pbindable_update :: (gfx: *Graphics_Device, resource: *$T/interface PBindable_Tag_Haver, user_data: *void = null) {
    #if resource.tag == {
        case .Constant_Buffer;
            // cbuffer_update(gfx, resource, user_data);
        case;
    }
}

pbindable_create :: (gfx: *Graphics_Device, resource: *$T/interface PBindable_Tag_Haver, user_data: *void = null, count : u32 = 1) -> bool {
    T : resource.T;
    if resource.tag == {
        case .Constant_Buffer;
            return cbuffer_create       (gfx, cast(*Constant_Buffer(type_of(T)))resource, user_data, count);
        case .Vertex_Buffer;
            return vertex_buffer_create (gfx, cast(*Vertex_Buffer(type_of(T)))resource, user_data, count);
        case;
            return false;
    }
}

sbindable_create :: (gfx: *Graphics_Device, resource: *$T/interface SBindable_Tag_Haver, user_data: *void = null, count : u32 = 1) -> bool {
    if resource.tag == {
        case .Index_Buffer;
            return index_buffer_create  (gfx, cast(*Index_Buffer)resource, user_data, count);
        case .Vertex_Shader;
            return vertex_shader_create (gfx, cast(*Vertex_Shader)resource, user_data);
        case .Pixel_Shader;
            return pixel_shader_create  (gfx, cast(*Pixel_Shader)resource, user_data);
        case .Input_Layout;
            return input_layout_create  (gfx, cast(*Input_Layout)resource, user_data);
        case;
            return false;
    }
}

#scope_file

cbuffer_bind  :: (using gfx: *Graphics_Device, cbuffer: *Constant_Buffer) {
    if cbuffer.cbuffer_type == {
        case .Vertex; ID3D11DeviceContext_VSSetConstantBuffers(d3d_context, cbuffer.slot, 1, *cbuffer.buffer);
        case .Pixel;  ID3D11DeviceContext_PSSetConstantBuffers(d3d_context, cbuffer.slot, 1, *cbuffer.buffer);
    }
}

cbuffer_create :: (using gfx: *Graphics_Device, cbuffer: *Constant_Buffer, user_data: *void, count: u32) -> bool {

    cbd : D3D11_BUFFER_DESC;
    cbd.Usage = .DYNAMIC;
    cbd.BindFlags = .CONSTANT_BUFFER;
    cbd.CPUAccessFlags = .WRITE;
    cbd.ByteWidth = size_of(cbuffer.T) * count;

    hr : HRESULT;
    if user_data != null {
        id : D3D11_SUBRESOURCE_DATA;
        id.pSysMem = user_data;
        hr := HR(ID3D11Device_CreateBuffer(d3d_device, *cbd, *id, *cbuffer.buffer));
    } else {
        hr = HR(ID3D11Device_CreateBuffer(d3d_device, *cbd, null, *cbuffer.buffer));
    }

    return SUCCEEDED(hr);
}

cbuffer_update :: (using gfx: *Graphics_Device, cbuffer: *Constant_Buffer, user_data: *void, count: u32) {
    
    mapped_data : D3D11_MAPPED_SUBRESOURCE;
    HR(ID3D11DeviceContext_Map(d3d_context, cbuffer.buffer, 0, .WRITE_DISCARD, 0, *mapped_data));
    memcpy(mapped_data.pData, user_data, size_of(cbuffer.T) * count);
    ID3D11DeviceContext_Unmap(d3d_context, cbufer.buffer, 0);
}

vertex_buffer_bind :: (using gfx: *Graphics_Device, vbuffer: *Vertex_Buffer) {

    stride : u32 = size_of(cbuffer.T);
    offset : u32 = 0; 
    ID3D11DeviceContext_IASetVertexBuffers(d3d_context, 0, 1, vbuffer.buffer, *stride, *offset);
}

vertex_buffer_create :: (using gfx: *Graphics_Device, vbuffer: *Vertex_Buffer, user_data: *void, count: u32) -> bool {

    vbd : D3D11_BUFFER_DESC;
    vbd.Usage = .DEFAULT;
    vbd.BindFlags = .VERTEX_BUFFER;
    vbd.CPUAccessFlags = 0;
    vbd.ByteWidth = size_of(vbuffer.T) * count;

    id : D3D11_SUBRESOURCE_DATA;
    id.pSysMem = user_data;
    hr := HR(ID3D11Device_CreateBuffer(d3d_device, *vbd, *id, *vbuffer.buffer));

    return SUCCEEDED(hr);
}

index_buffer_bind :: (using gfx: *Graphics_Device, ibuffer: *Index_Buffer) {

    ID3D11DeviceContext_IASetIndexBuffer(d3d_context, ibuffer.buffer, .R32_UINT, 0);
}

index_buffer_create :: (using gfx: *Graphics_Device, ibuffer: *Index_Buffer, user_data: *void, count: u32) -> bool {

    ibd : D3D11_BUFFER_DESC;
    ibd.Usage = .DEFAULT;
    ibd.BindFlags = .INDEX_BUFFER;
    ibd.CPUAccessFlags = 0;
    ibd.ByteWidth = size_of(u32) * count;

    id : D3D11_SUBRESOURCE_DATA;
    id.pSysMem = user_data;
    hr := HR(ID3D11Device_CreateBuffer(d3d_device, *ibd, *id, *ibuffer.buffer));

    return SUCCEEDED(hr);
}

input_layout_create :: (using gfx: *Graphics_Device, input_layout: *Input_Layout, user_data : *void) -> bool {

    using input_layout_desc := cast(*Input_Layout_Desc)user_data;
    hr := HR(ID3D11Device_CreateInputLayout(d3d_device, layout.data, cast(u32) layout.count, bytecode.data, cast(u64) bytecode.count, *input_layout.il));
    return SUCCEEDED(hr);
}

input_layout_bind :: (using gfx: *Graphics_Device, input_layout: *Input_Layout, user_data : *void) {

    ID3D11DeviceContext_IASetInputLayout(d3d_context, input_layout.il);
}

vertex_shader_create :: (using gfx: *Graphics_Device, vshader: *Vertex_Shader, user_data : *void) -> bool {

    vshader.bytecode = compile_shader(to_string(user_data), "VS", "vs_5_0");
    assert(vshader.bytecode.data != null);

    hr := HR(ID3D11Device_CreateVertexShader(d3d_device, vshader.bytecode.data, cast(u64) vshader.bytecode.count, null, *vshader.shader));
    return SUCCEEDED(hr);
}

vertex_shader_bind :: (using gfx: *Graphics_Device, pshader: *Vertex_Shader, user_data : *void) {
}

pixel_shader_create :: (using gfx: *Graphics_Device, vshader: *Pixel_Shader, user_data : *void) -> bool {
    return true;
}

pixel_shader_bind :: (using gfx: *Graphics_Device, pshader: *Pixel_Shader, user_data : *void) {
}
