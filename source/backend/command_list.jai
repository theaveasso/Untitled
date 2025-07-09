D3D12CommandList :: struct {
    cmdlist:    *ID3D12GraphicsCommandList;
    allocator:  *D3D12CommandAllocator;

    accumulate_barriers: [..]D3D12_RESOURCE_BARRIER;

    current_bind_graphics_root_signature: *D3D12Root_Signature;
    current_bind_compute\_root_signature: *D3D12Root_Signature;
}

d3d12_cmd_list_init :: (using _device: *D3D12Device, using _cmdlist: *D3D12CommandList) -> bool {

    ok: bool;
    if allocator.type == {
        case .GRAPHICS; ok = HR(ID3D12Device_CreateCommandList(device, 0, .DIRECT, allocator.allocator, null, *uid(ID3D12GraphicsCommandList_UUID), xx *cmdlist));
        case .COMPUTE;  ok = HR(ID3D12Device_CreateCommandList(device, 0, .COMPUTE, allocator.allocator, null, *uid(ID3D12GraphicsCommandList_UUID), xx *cmdlist));
        case .COPY;     ok = HR(ID3D12Device_CreateCommandList(device, 0, .COPY, allocator.allocator, null, *uid(ID3D12GraphicsCommandList_UUID), xx *cmdlist));
    }

    return ok;
}

d3d12_cmd_list_release :: inline (using _cmdlist: *D3D12CommandList) { safe_release(cmdlist); }

d3d12_cmd_list_bind_graphics_root_signature :: inline (using _cmdlist: *D3D12CommandList, root: *D3D12Root_Signature, bind_resource: bool = true) {

    ID3D12GraphicsCommandList_SetGraphicsRootSignature(cmdlist, root.root_signature);
    current_bind_graphics_root_signature = root;

    if bind_resource {
        for root.parameters {
            if it.resource == null continue;
            if it.type == {
                case .ROOTCONSTANT;
                    ID3D12GraphicsCommandList_SetGraphicsRoot32BitConstants(cmdlist, xx it_index, it.res_counts, it.constant_data, 0);
                case .CBV;
                    if it.is_table && it.res_counts != 1 {
                        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(cmdlist, xx it_index, it.resource.cbv.gpu);
                    } else {
                        ID3D12GraphicsCommandList_SetGraphicsRootConstantBufferView(cmdlist, xx it_index, it.resource.gpu_addr);
                    }
                case .SRV;
                    if it.is_table {
                        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(cmdlist, xx it_index, it.resource.srv.gpu);
                    } else {
                        ID3D12GraphicsCommandList_SetGraphicsRootUnorderedAccessView(cmdlist, xx it_index, it.resource.gpu_addr);
                    }
                case .UAV; 
                    if it.is_table {
                        ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(cmdlist, xx it_index, it.resource.uavs[it.uav_mip_level].gpu);
                    } else {
                        ID3D12GraphicsCommandList_SetGraphicsRootUnorderedAccessView(cmdlist, xx it_index, it.resource.gpu_addr);
                    }
                case .SAMPLER; 
                    ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(cmdlist, xx it_index, it.sampler.sampler.gpu);
                case;
            }
        }
    }
}

d3d12_cmd_list_bind_graphics_sampler :: inline (using _cmdlist: *D3D12CommandList, root_index: u32, sampler: *D3D12Sampler) { ID3D12GraphicsCommandList_SetGraphicsRootDescriptorTable(cmdlist, root_index, sampler.sampler.gpu); }

d3d12_cmd_list_bind_heap    :: inline (using _cmdlist: *D3D12CommandList, heaps: **ID3D12DescriptorHeap, counts: u32 = 1) { ID3D12GraphicsCommandList_SetDescriptorHeaps(cmdlist, counts, heaps); }
d3d12_cmd_list_bind_vbuffer :: inline (using _cmdlist: *D3D12CommandList, buffer: *D3D12Buffer) { ID3D12GraphicsCommandList_IASetVertexBuffers(cmdlist, 0, 1, *buffer.vbv); }
d3d12_cmd_list_bind_ibuffer :: inline (using _cmdlist: *D3D12CommandList, buffer: *D3D12Buffer) { ID3D12GraphicsCommandList_IASetIndexBuffer(cmdlist, *buffer.ibv); }
d3d12_cmd_list_bind_rt      :: inline (using _cmdlist: *D3D12CommandList, buffer: *Swapchain_Buffer) { ID3D12GraphicsCommandList_OMSetRenderTargets(cmdlist, 1, *buffer.rtvs[0].cpu, .FALSE, null); }

d3d12_cmd_list_set_viewport :: inline (using _cmdlist: *D3D12CommandList, viewport: *D3D12_VIEWPORT) { ID3D12GraphicsCommandList_RSSetViewports(cmdlist, 1, viewport); }
d3d12_cmd_list_set_scissor  :: inline (using _cmdlist: *D3D12CommandList, scissor: *D3D12_RECT) { ID3D12GraphicsCommandList_RSSetScissorRects(cmdlist, 1, scissor); }
d3d12_cmd_list_set_topology :: inline (using _cmdlist: *D3D12CommandList, topology: D3D12_PRIMITIVE_TOPOLOGY) { ID3D12GraphicsCommandList_IASetPrimitiveTopology(cmdlist, topology); }

d3d12_cmd_list_clear_rtv    :: inline (using _cmdlist: *D3D12CommandList, buffer: *Swapchain_Buffer, color: *[4]float) { ID3D12GraphicsCommandList_ClearRenderTargetView(cmdlist, buffer.rtvs[0].cpu, color, 0, null); }

d3d12_cmd_list_draw_index_instanced :: inline (using _cmdlist: *D3D12CommandList, index_count_per_instance: u32, instance_count: u32, start_index_location: u32, base_vertex_location: s32, start_instance_location: u32 = 0) { ID3D12GraphicsCommandList_DrawIndexedInstanced(cmdlist, index_count_per_instance, instance_count, start_index_location, base_vertex_location, start_instance_location); }

d3d12_cmd_list_close :: inline (using _cmdlist: *D3D12CommandList) -> bool { return HR(ID3D12GraphicsCommandList_Close(cmdlist)); }

d3d12_cmd_list_update_buffer_data :: inline (using _cmdlist: *D3D12CommandList, buffer: *D3D12Buffer, data: *void, size: s64) -> bool {

    if !buffer.resource || !buffer.upload_buffer {
        log_error("Before able to update buffer data, buffer need to be create!");
        return false;
    }

    read_range: D3D12_RANGE = .{0, 0};
    map_addr: *void;
    ID3D12Resource_Map(buffer.upload_buffer, 0, *read_range, *map_addr);
    memcpy(map_addr, data, size);
    ID3D12GraphicsCommandList_CopyBufferRegion(cmdlist, buffer.resource, 0, buffer.upload_buffer, 0, xx size);
    ID3D12Resource_Unmap(buffer.upload_buffer, 0, null);
    
    return true;
}

d3d12_cmd_list_update_texture_data :: inline (using _cmdlist: *D3D12CommandList, using _texture: *D3D12Texture, data: *void, start_level: s32 = 0, level_num: s32 = 1, start_slice: s32 = 0, slice_num: s32 = 1) -> bool {

    if !resource || !upload_buffer {
        log_error("Before able to update buffer data, texture need to be create!");
        return false;
    }

    levels := min((desc.MipLevels - start_level), level_num);
    slices := min((desc.DepthOrArraySize - start_slice), slice_num);

    Data: [] D3D12_SUBRESOURCE_DATA; 
    Data = NewArray(levels, D3D12_SUBRESOURCE_DATA);
    
    cpu_offset: s64 = 0;
    gpu_offset: s64 = 0;

    _slices := start_slice + slices;
    _levels := start_level + levels;
    for i: start_slice.._slices - 1 {
        start_sub := i * desc.MipLevels + start_level;
        gpu_offset = xx layouts[start_sub].Offset;
        for j: start_level.._levels - 1 {
            subnum := i * desc.MipLevels + j;
            cpumiplevel := j - start_level;
            Data[cpumiplevel].pData = data + cpu_offset;
            Data[cpumiplevel].RowPitch = layouts[subnum].Footprint.Width * bytesize;
            Data[cpumiplevel].SlicePitch = layouts[subnum].Footprint.Height * Data[cpumiplevel].RowPitch;
            cpu_offset += Data[cpumiplevel].SlicePitch;
        }
        update_subresource(cmdlist, resource, upload_buffer, gpu_offset, xx start_sub, xx levels, Data.data);

        array_free(Data);
    }

    return true;
}

d3d12_cmd_list_resource_transition :: inline (using _cmdlist: *D3D12CommandList, res: *GPU_Resource, stataf: D3D12_RESOURCE_STATES, barrier: bool = false, subresource:= D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, flags: D3D12_RESOURCE_BARRIER_FLAGS = .NONE) {

    if subresource == D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES {
        if res.states[0] == stataf return;
    } else {
        if res.states[subresource] == stataf return;
    }

    transition: D3D12_RESOURCE_BARRIER;
    transition.Type    = .TRANSITION;
    transition.Flags   = flags;

    transition.Transition.pResource    = res.resource;
    transition.Transition.Subresource  = xx subresource;
    transition.Transition.StateAfter   = stataf;
    if subresource == D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES {
        transition.Transition.StateBefore  = res.states[0];
        for *res.states {
            it.* = stataf;
        }
    } else {
        transition.Transition.StateBefore  = res.states[subresource];
        res.states[subresource] = stataf;
    }

    array_add(*accumulate_barriers, transition);
    if barrier set_barrier(_cmdlist);
}

d3d12_cmd_list_swapchain_buffer_transition :: (using _cmdlist: *D3D12CommandList, res: *Swapchain_Buffer, stataf: D3D12_RESOURCE_STATES, barrier := false, subresource := D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES, flags: D3D12_RESOURCE_BARRIER_FLAGS = .NONE) {

    if res.states[0] != stataf {
        transition: D3D12_RESOURCE_BARRIER;
        transition.Type    = .TRANSITION;
        transition.Flags   = flags;

        transition.Transition.pResource    = res.resource;
        transition.Transition.Subresource  = xx subresource;
        transition.Transition.StateAfter   = stataf;
        transition.Transition.StateBefore  = res.states[0];

        res.states[0] = stataf;
        array_add(*accumulate_barriers, transition);
    }

    if barrier set_barrier(_cmdlist);
}

d3d12_cmd_list_reset :: inline (using _cmdlist: *D3D12CommandList, infoqueue: *ID3D12InfoQueue = null) -> bool { return HR(ID3D12GraphicsCommandList_Reset(cmdlist, allocator.allocator, null)); }
d3d12_cmd_list_reset :: inline (using _cmdlist: *D3D12CommandList, pipeline: *D3D12Pipeline, infoqueue: *ID3D12InfoQueue = null) -> bool { return HR(ID3D12GraphicsCommandList_Reset(cmdlist, allocator.allocator, pipeline.pipeline)); }


d3d12_cmd_list_reset_w_allocator :: inline (using _cmdlist: *D3D12CommandList, infoqueue: *ID3D12InfoQueue = null) -> bool {
    
    ok: bool;
    ok = d3d12_cmd_allocator_reset(allocator, infoqueue);
    if !ok return false;
    ok = d3d12_cmd_list_reset(_cmdlist, infoqueue);

    return true;
}

d3d12_cmd_list_reset_w_allocator :: inline (using _cmdlist: *D3D12CommandList, pipeline: *D3D12Pipeline, infoqueue: *ID3D12InfoQueue = null) -> bool {
    
    ok: bool;
    ok = d3d12_cmd_allocator_reset(allocator, infoqueue);
    if !ok return false;
    ok = d3d12_cmd_list_reset(_cmdlist, pipeline, infoqueue);

    return true;
}

#scope_file

set_barrier :: inline (using _cmdlist: *D3D12CommandList) {

    if accumulate_barriers.count > 0 ID3D12GraphicsCommandList_ResourceBarrier(cmdlist, xx accumulate_barriers.count, accumulate_barriers.data);
    array_reset(*accumulate_barriers);
}