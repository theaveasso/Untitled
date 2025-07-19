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

command_list_reset_w_allocator :: inline (using command_list: *Command_List) { 
    ID3D12CommandAllocator_Reset(allocator);
    ID3D12GraphicsCommandList_Reset(cmdlist, allocator, null); 
}
command_list_reset_w_allocator :: inline (using command_list: *Command_List, pipeline: *ID3D12PipelineState) { 
    ID3D12CommandAllocator_Reset(allocator);
    ID3D12GraphicsCommandList_Reset(cmdlist, allocator, pipeline); 
}

command_list_reset             :: inline (using command_list: *Command_List) { ID3D12GraphicsCommandList_Reset(cmdlist, null, null); }
command_list_reset             :: inline (using command_list: *Command_List, pipeline: *ID3D12PipelineState) { ID3D12GraphicsCommandList_Reset(cmdlist, null, pipeline); }

command_list_close             :: inline (using command_list: *Command_List) { ID3D12GraphicsCommandList_Close(cmdlist); }

command_list_execute           :: inline (cmdq: *ID3D12CommandQueue, cmdlist_counts: s64, cmdlist_data: **ID3D12CommandList) { ID3D12CommandQueue_ExecuteCommandLists(xx cmdq, xx cmdlist_counts, cmdlist_data); }

commandlist_upload_buffer_data :: (command_list: *Command_List, buffer: *Buffer, data: *void, size: s64) -> bool {

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