Texture_Usage :: enum_flags u32 {
    SRV         :: 0x01;
    UAV         :: 0x02;
    RTV         :: 0x04;
    DSV         :: 0x08;
    SRV_DSV     :: SRV | DSV; 
    SRV_UAV     :: SRV | UAV;
    SRV_RTV     :: SRV | RTV;
    SRV_RTV_UAV :: SRV | RTV | UAV;
}

Texture_SRV_Type :: enum u8 {
    TEXTURE_2D;
    TEXTURE_3D;
    TEXTURE_CUBE;
}

Texture_ALL_Mips_Use :: enum_flags u32 {
    NONE :: 0x00;
    UAV  :: 0x01;
    RTV  :: 0x02;
    DSV  :: 0x04;
    ALL  :: UAV | RTV | DSV;
}

D3D12Texture :: struct {
    using #as base: GPU_Resource;

    desc: D3D12_RESOURCE_DESC;
    clear_value: D3D12_CLEAR_VALUE;
    usage: D3D12_RESOURCE_FLAGS;
}