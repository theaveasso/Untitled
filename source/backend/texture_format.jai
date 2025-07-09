
get_image_bytes_per_texel :: (tf: DXGI_FORMAT) -> int {
    using DXGI_FORMAT;

    if tf == {
        case R8_TYPELESS;           #through;
        case R8G8_SINT;             #through;
        case R16_FLOAT;             #through;
        case D16_UNORM;             return 2;
        case R8G8B8A8_TYPELESS;     #through;
        case R8G8B8A8_UNORM;        #through;
        case R8G8B8A8_UNORM_SRGB;   #through;
        case R8G8B8A8_UINT;         #through;
        case R8G8B8A8_SNORM;        #through;
        case R8G8B8A8_SINT;         #through;
        case R16G16_TYPELESS;       #through;
        case R16G16_FLOAT;          #through;
        case R16G16_UNORM;          #through;
        case R16G16_UINT;           #through;
        case R16G16_SNORM;          #through;
        case R16G16_SINT;           #through;
        case R32_TYPELESS;          #through;
        case D32_FLOAT;             return 4;
        case R16G16B16A16_TYPELESS; #through;
        case R16G16B16A16_FLOAT;    #through;
        case R16G16B16A16_UNORM;    #through;
        case R16G16B16A16_SNORM;    #through;
        case R16G16B16A16_SINT;     #through;
        case R32G32_TYPELESS;       #through;
        case R32G32_FLOAT;          #through;
        case R32G32_UINT;           #through;
        case R32G32_SINT;           return 8;
        case R32G32B32_UINT;        #through;
        case R32G32B32_SINT;        return 12;
        case R32G32B32A32_TYPELESS; #through;
        case R32G32B32A32_FLOAT;    #through;
        case R32G32B32A32_UINT;     #through;
        case R32G32B32A32_SINT;     #through;
        case R32G32B32_TYPELESS;    #through;
        case R32G32B32_FLOAT;       return 16;
    }

    return 0;
}