Command_List :: struct {
    type:       D3D12_COMMAND_LIST_TYPE;
    cmdlist:    *ID3D12GraphicsCommandList;
    allocator:  *ID3D12CommandAllocator;
}

make_command_list :: (allocator: *ID3D12CommandAllocator, type: D3D12_COMMAND_LIST_TYPE = .DIRECT) -> success: bool, Command_List {

    CheckInit();
    using state.d3d12;

    ret: Command_List;
    ret.allocator = allocator;
    ret.type      = type;

    success := HR(ID3D12Device_CreateCommandList(device, 0, type, allocator, null,  *uid(ID3D12CommandList_UUID), xx *ret.cmdlist));
    if !success return false, .{};

    return true, ret;
}

deinit :: (command_list: *Command_List) {

    safe_release_and_reset(*command_list.cmdlist);
}

commandlist_reset_w_allocator :: inline (using command_list: *Command_List) { 
    ID3D12CommandAllocator_Reset(allocator);
    ID3D12GraphicsCommandList_Reset(cmdlist, allocator, null); 
}

commandlist_reset_w_allocator :: inline (using command_list: *Command_List, pipeline: *ID3D12PipelineState) { 
    ID3D12CommandAllocator_Reset(allocator);
    ID3D12GraphicsCommandList_Reset(cmdlist, allocator, pipeline); 
}

commandlist_reset               :: inline (using command_list: *Command_List) { ID3D12GraphicsCommandList_Reset(cmdlist, null, null); }

commandlist_reset               :: inline (using command_list: *Command_List, pipeline: *ID3D12PipelineState) { ID3D12GraphicsCommandList_Reset(cmdlist, null, pipeline); }

commandlist_resource_transition :: inline (using command_list: *Command_List, resource: *ID3D12Resource, state_before: D3D12_RESOURCE_STATES, state_after: D3D12_RESOURCE_STATES) { ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, 1, *D3D12_RESOURCE_BARRIER_INIT_AS_TRANSITION(resource, state_before, state_after)); }

commandlist_close               :: inline (using command_list: *Command_List) { ID3D12GraphicsCommandList_Close(cmdlist); }

commandlist_execute             :: inline (cmdq: *ID3D12CommandQueue, cmdlist_counts: s64, cmdlist_data: **ID3D12CommandList) { ID3D12CommandQueue_ExecuteCommandLists(xx cmdq, xx cmdlist_counts, cmdlist_data); }

commandlist_update_buffer_data  :: (command_list: *Command_List, buffer: *Buffer, data: *void, size: s64) -> bool {

    CheckInit();
    using state.d3d12;

    if !buffer.resource || !buffer.upload_buffer {
        log_error("commandlist_upload_buffer_data: Failed Buffer is not initialized!");
        return false;
    }

    read_range: D3D12_RANGE;
    map_addr: *void;
    ID3D12Resource_Map(buffer.upload_buffer, 0, *read_range, *map_addr);
    memcpy(map_addr, data, size);

    ID3D12GraphicsCommandList_CopyBufferRegion(xx command_list.cmdlist, buffer.resource, 0, buffer.upload_buffer, 0, xx size);
    ID3D12Resource_Unmap(buffer.upload_buffer, 0, null);

    return true;
}

commandlist_update_texture_data :: (command_list: *Command_List, _texture: *Texture, data: *void, start_level: s32 = 0, level_counts: s32 = 1, start_slice: s32 = 0, slice_counts: s32 = 1) -> bool {

    CheckInit();
    using state.d3d12;

    if !_texture.resource || !_texture.upload_buffer {
        log_error("commandlist_upload_texture_data: Failed Texture is not initialized!");
        return false;
    }

    levels := min(_texture.resource_desc.MipLevels - start_level, level_counts);
    slices := min(_texture.resource_desc.DepthOrArraySize - start_slice, slice_counts);

    cpu_offset: s64 = 0;
    gpu_offset: s64 = 0;

    _levels := start_level + levels;
    _slices := start_slice + slices;

    Data: [] D3D12_SUBRESOURCE_DATA;
    Data = NewArray(levels, D3D12_SUBRESOURCE_DATA);

    for i: start_slice.._slices - 1 {
        start_subresource := i * _texture.resource_desc.MipLevels + start_level;
        gpu_offset = xx _texture.layouts[start_subresource].Offset;
        for j: start_level.._levels - 1 {
            sub_num  := i * _texture.resource_desc.MipLevels + j;
            cpumiplevel := j - start_level;
            Data[cpumiplevel].pData = data + cpu_offset;
            Data[cpumiplevel].RowPitch      = _texture.layouts[sub_num].Footprint.Width * xx _texture.bpp;
            Data[cpumiplevel].SlicePitch    = _texture.layouts[sub_num].Footprint.Height * Data[cpumiplevel].RowPitch;
            cpu_offset += Data[cpumiplevel].SlicePitch;
        }

        UpdateSubresource(command_list.cmdlist, _texture.resource, _texture.upload_buffer, gpu_offset, xx start_subresource, xx levels, Data.data);
    }

    array_free(Data);
    return true;
}