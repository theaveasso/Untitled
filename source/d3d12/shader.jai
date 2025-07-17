Shader :: struct {
    type:       Shader_Type;
    reflector:  *ID3D12ShaderReflection;

    shader:     *ID3D10Blob;
    desc:       D3D12_SHADER_DESC;
}

Input_Layout_Type :: enum u8 {
    NON_SPLIT;
    SPLIT_ALL;
}

Shader_Type :: enum u32 {
    VS;
    PS;
}

shader_get_input_element :: (using _shader: Shader, layout: Input_Layout_Type) -> [..] D3D12_INPUT_ELEMENT_DESC {

    ret: [..] D3D12_INPUT_ELEMENT_DESC;
    input_desc: D3D12_SIGNATURE_PARAMETER_DESC;
    input_elem: D3D12_INPUT_ELEMENT_DESC;
    byteoffset: u32 = 0;
    slot:       u32 = 0;

    instance_name := "SV_InstanceID";
    index\  _name := "SV_VertexID";
    primitive_name:= "SV_PrimitiveID";

    for i: 0..desc.InputParameters - 1 {

        ID3D12ShaderReflection_GetInputParameterDesc(reflector, xx i, *input_desc);
        input_elem.SemanticName = input_desc.SemanticName;
        t := to_string(input_elem.SemanticName);

        if t == instance_name || t == index_name || t == primitive_name continue;

        input_elem.SemanticIndex = input_desc.SemanticIndex;
        input_elem.InputSlot     = slot;
        if layout == .SPLIT_ALL {
            slot        +=1;
            byteoffset  = 0;
        }
        input_elem.AlignedByteOffset    = byteoffset;
        input_elem.InputSlotClass       = .PER_VERTEX_DATA;
        input_elem.InstanceDataStepRate = 0;

        if input_desc.Mask == {
            case 1;
                     if input_desc.ComponentType == .REGISTER_COMPONENT_UINT32  input_elem.Format = .R32_UINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_SINT32  input_elem.Format = .R32_SINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_FLOAT32 input_elem.Format = .R32_FLOAT;
                byteoffset += 4;
                array_add(*ret, input_elem);
            case 3;
                     if input_desc.ComponentType == .REGISTER_COMPONENT_UINT32  input_elem.Format = .R32G32_UINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_SINT32  input_elem.Format = .R32G32_SINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_FLOAT32 input_elem.Format = .R32G32_FLOAT;
                byteoffset += 8;
                array_add(*ret, input_elem);
            case 7;
                if input_desc.ComponentType      == .REGISTER_COMPONENT_UINT32  input_elem.Format = .R32G32B32_UINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_SINT32  input_elem.Format = .R32G32B32_SINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_FLOAT32 input_elem.Format = .R32G32B32_FLOAT;
                byteoffset += 12;
                array_add(*ret, input_elem);
            case 15;
                if input_desc.ComponentType      == .REGISTER_COMPONENT_UINT32  input_elem.Format = .R32G32B32A32_UINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_SINT32  input_elem.Format = .R32G32B32A32_SINT;
                else if input_desc.ComponentType == .REGISTER_COMPONENT_FLOAT32 input_elem.Format = .R32G32B32A32_FLOAT;
                byteoffset += 16;
                array_add(*ret, input_elem);
        }
    }

    return ret;
}