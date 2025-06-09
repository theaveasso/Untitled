// MIT License
//
// Copyright(c) 2023 Jordan Peck (jordan.me2@gmail.com)
// Copyright(c) 2023 Contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
// .'',;:cldxkO00KKXXNNWWWNNXKOkxdollcc::::::;:::ccllloooolllllllllooollc:,'...        ...........',;cldxkO000Okxdlc::;;;,,;;;::cclllllll
// ..',;:ldxO0KXXNNNNNNNNXXK0kxdolcc::::::;;;,,,,,,;;;;;;;;;;:::cclllllc:;'....       ...........',;:ldxO0KXXXK0Okxdolc::;;;;::cllodddddo
// ...',:loxO0KXNNNNNXXKK0Okxdolc::;::::::::;;;,,'''''.....''',;:clllllc:;,'............''''''''',;:loxO0KXNNNNNXK0Okxdollccccllodxxxxxxd
// ....';:ldkO0KXXXKK00Okxdolcc:;;;;;::cclllcc:;;,''..... ....',;clooddolcc:;;;;,,;;;;;::::;;;;;;:cloxk0KXNWWWWWWNXKK0Okxddoooddxxkkkkkxx
// .....';:ldxkOOOOOkxxdolcc:;;;,,,;;:cllooooolcc:;'...      ..,:codxkkkxddooollloooooooollcc:::::clodkO0KXNWWWWWWNNXK00Okxxxxxxxxkkkkxxx
// . ....';:cloddddo___________,,,,;;:clooddddoolc:,...      ..,:ldx__00OOOkkk___kkkkkkxxdollc::::cclodkO0KXXNNNNNNXXK0OOkxxxxxxxxxxxxddd
// .......',;:cccc:|           |,,,;;:cclooddddoll:;'..     ..';cox|  \KKK000|   |KK00OOkxdocc___;::clldxxkO0KKKKK00Okkxdddddddddddddddoo
// .......'',,,,,''|   ________|',,;;::cclloooooolc:;'......___:ldk|   \KK000|   |XKKK0Okxolc|   |;;::cclodxxkkkkxxdoolllcclllooodddooooo
// ''......''''....|   |  ....'',,,,;;;::cclloooollc:;,''.'|   |oxk|    \OOO0|   |KKK00Oxdoll|___|;;;;;::ccllllllcc::;;,,;;;:cclloooooooo
// ;;,''.......... |   |_____',,;;;____:___cllo________.___|   |___|     \xkk|   |KK_______ool___:::;________;;;_______...'',;;:ccclllloo
// c:;,''......... |         |:::/     '   |lo/        |           |      \dx|   |0/       \d|   |cc/        |'/       \......',,;;:ccllo
// ol:;,'..........|    _____|ll/    __    |o/   ______|____    ___|   |   \o|   |/   ___   \|   |o/   ______|/   ___   \ .......'',;:clo
// dlc;,...........|   |::clooo|    /  |   |x\___   \KXKKK0|   |dol|   |\   \|   |   |   |   |   |d\___   \..|   |  /   /       ....',:cl
// xoc;'...  .....'|   |llodddd|    \__|   |_____\   \KKK0O|   |lc:|   |'\       |   |___|   |   |_____\   \.|   |_/___/...      ...',;:c
// dlc;'... ....',;|   |oddddddo\          |          |Okkx|   |::;|   |..\      |\         /|   |          | \         |...    ....',;:c
// ol:,'.......',:c|___|xxxddollc\_____,___|_________/ddoll|___|,,,|___|...\_____|:\ ______/l|___|_________/...\________|'........',;::cc
// c:;'.......';:codxxkkkkxxolc::;::clodxkOO0OOkkxdollc::;;,,''''',,,,''''''''''',,'''''',;:loxkkOOkxol:;,'''',,;:ccllcc:;,'''''',;::ccll
// ;,'.......',:codxkOO0OOkxdlc:;,,;;:cldxxkkxxdolc:;;,,''.....'',;;:::;;,,,'''''........,;cldkO0KK0Okdoc::;;::cloodddoolc:;;;;;::ccllooo
// .........',;:lodxOO0000Okdoc:,,',,;:clloddoolc:;,''.......'',;:clooollc:;;,,''.......',:ldkOKXNNXX0Oxdolllloddxxxxxxdolccccccllooodddd
// .    .....';:cldxkO0000Okxol:;,''',,;::cccc:;,,'.......'',;:cldxxkkxxdolc:;;,'.......';coxOKXNWWWNXKOkxddddxxkkkkkkxdoollllooddxxxxkkk
//       ....',;:codxkO000OOxdoc:;,''',,,;;;;,''.......',,;:clodkO00000Okxolc::;,,''..',;:ldxOKXNWWWNNK0OkkkkkkkkkkkxxddooooodxxkOOOOO000
//       ....',;;clodxkkOOOkkdolc:;,,,,,,,,'..........,;:clodxkO0KKXKK0Okxdolcc::;;,,,;;:codkO0XXNNNNXKK0OOOOOkkkkxxdoollloodxkO0KKKXXXXX
//
// VERSION: 1.1.1
// https://github.com/Auburn/FastNoiseLite

FNL_State :: struct {
    seed                : s32   = 42;
    frequency           : float = 0.01; 
    octaves             : int   = 3;
    lacunarity          : float = 2.0;
    gain                : float = 0.5;
    weighted_strength   : float = 0.0;
    noise_type          : FNL_Noise_Type    = .OpenSimplex2S;
    fractal_type        : FNL_Fractal_Type  = .None;
}

FNL_Noise_Type :: enum u8 {
    Perlin;
    OpenSimplex2;
    OpenSimplex2S;
}

FNL_Fractal_Type :: enum u8 {
    None;
    FBM;
}

// 2D noise at given position using the state settings
// @returns Noise output bounded between -1 and 1.
get_noise_2d :: (using fnl_state : *FNL_State, x : float, y : float) -> float {
    // transform_noise_coordinate_2d
    x *= frequency;
    y *= frequency;

    if noise_type == {
        case .OpenSimplex2; #through;
        case .OpenSimplex2S;
            SQRT3 := 1.7320508075688772935274463415059;
            F2    := 0.5 * (SQRT3 - 1);
            t := (x + y) * F2;
            x += xx t;
            y += xx t;
        case;
    }


    if fractal_type == {
        case .FBM; return gen_fractal_fbm_2d(fnl_state, x, y);
        case;      return gen_noise_single_2d(fnl_state, seed, x, y);
    } 
}

gen_noise_single_2d :: (using fnl_state : *FNL_State, next_seed : s32, x : float, y : float) -> float {
    if noise_type == {
        case .OpenSimplex2;     return _fnl_single_open_simplex_2d(next_seed, x, y);
        case .OpenSimplex2S;    return _fnl_single_open_simplex_2s_2d(next_seed, x, y);
        case .Perlin;           return _fnl_single_perlin_2d(next_seed, x, y);
        case; return 0;
    }
}

#scope_file

PRIME_X :: 501125321;
PRIME_Y :: 1136930381;
PRIME_Z :: 1720413743;

// Utilities
fast_min        :: inline (x : float, y : float) -> float { return ifx x < y then x else y; }
fast_abs        :: inline (f : float) -> float { return ifx f < 0 then -f else f; }
fast_floor      :: inline (f : float) -> int { return ifx f >= 0 then cast(int) f else cast(int) f - 1; }
interp_quintic  :: inline (t :float) -> float { return t * t * t * (t * (t * 6 - 15) + 10); }

hash_2d         :: inline (seed : int, x : int, y : int) -> int { hash := seed ^ x ^ y; hash *= 0x27d4eb2d; return hash; } 
grad_coord_2d   :: inline (seed : int, x : int, y : int, xd : float, yd : float) -> float { hash := hash_2d(seed, x, y); hash ^= hash >> 15; hash &= 127 << 1; return xd * xx GRADIENTS_2D[hash] + yd * xx GRADIENTS_2D[hash | 1]; }

calculate_fractal_bounding :: (fnl_state : *FNL_State) -> float {
    gain := fast_abs(fnl_state.gain);
    amp  := gain;
    amp_fractal := 1.0;

    for 1..fnl_state.octaves {
        amp_fractal += amp;
        amp *= gain;
    }

    return 1.0 / amp_fractal;
}

// Simplex/OpenSimplex2 Noise
_fnl_single_open_simplex_2d     :: inline (seed : s32, x : float, y : float) -> float {
    SQRT3 := 1.7320508075688772935274463415059;
    G2    := (3 - SQRT3) / 6;

    i  := fast_floor(x);
    j  := fast_floor(y);
    xi := cast(float)(x - i);
    yi := cast(float)(y - j);

    t  := (xi + yi) * G2;
    x0 := cast(float)(xi - t);
    y0 := cast(float)(yi - t);

    i *= PRIME_X;
    j *= PRIME_Y;

    n0, n1, n2 : float64;

    a := 0.5 - x0 * x0 - y0 * y0;
    if a <= 0 { 
        n0 = 0;
    } else { 
        n0 = (a * a) * (a * a) * xx grad_coord_2d(seed, i, j, x0, y0); 
    }

    c := cast(float)(2 * (1 - 2 * G2) * (1 / G2 - 2)) * t + (cast(float)(-2 * (1 - 2 * G2) * (1 - 2 * G2)) + a);
    if c <= 0 {
        n2 = 0;
    } else {
        x2 := x0 + (2 * cast(float)G2 - 1);
        y2 := y0 + (2 * cast(float)G2 - 1);
        n2 = (c * c) * (c * c) * xx grad_coord_2d(seed, i + PRIME_X, j + PRIME_Y, x2, y2);
    }

    if (y0 > x0) {
        x1 := x0 + xx G2;
        y1 := y0 + xx (G2 - 1);
        b := 0.5 - x1 * x1 - y1 * y1;
        if b <= 0 {
            n1 = 0;
        } else {
            n1 = (b * b) * (b * b) * xx grad_coord_2d(seed, i, j + PRIME_Y, x1, y1);
        }
    } else {
        x1 := x0 + xx (G2 - 1);
        y1 := y0 + xx  G2;
        b  := 0.5 - x1 * x1 - y1 * y1;
        if (b < 0) {
            n1 = 0;
        } else {
            n1 = (b * b) * (b * b) * xx grad_coord_2d(seed, i + PRIME_X, j, x1, y1);
        }

    }

    return cast(float)((n0 + n1 + n2) * 99.83685446303647);
}

_fnl_single_open_simplex_2s_2d  :: inline (seed : s32, x : float, y : float) -> float {
    SQRT3 := 1.7320508075688772935274463415059;
    G2    := (3 - SQRT3) / 6;

    i  := fast_floor(x);
    j  := fast_floor(y);
    xi := cast(float)(x - i);
    yi := cast(float)(y - j);

    i *= PRIME_X;
    j *= PRIME_Y;
    i1 := cast(int) i + PRIME_X;
    j1 := cast(int) j + PRIME_Y;

    t  := (xi + yi) * G2;
    x0 := xi - t;
    y0 := yi - t;

    a0 := (2.0 / 3.0) - x0 * x0 - y0 * y0;
    value := (a0 * a0) * (a0 * a0) * grad_coord_2d(seed, i, j, xx x0, xx y0);

    a1 := cast(float)(2 * (1 - 2 * G2) * (1 / G2 - 2)) * t + (cast(float)(-2 * (1 - 2 * G2) * (1 - 2 * G2)) + a0);
    x1 := x0 - cast(float)(1 - 2 * G2);
    y1 := y0 - cast(float)(1 - 2 * G2);
    value += (a1 * a1) * (a1 * a1) * grad_coord_2d(seed, i1, j1, xx x1, xx y1);

    xmyi := xi - yi;
    if t > G2 {
        if xi + xmyi > 1 {
            x2 := x0 + cast(float)(3 * G2 - 2);
            y2 := y0 + cast(float)(3 * G2 - 1);
            a2 := (2.0 / 3.0) - x2 * x2 - y2 * y2;
            if a2 > 0 value += (a2 * a2) * (a2 * a2) * xx grad_coord_2d(seed, i + (PRIME_X << 1), j + PRIME_Y, xx x2, xx y2);
        } else {
            x2 := x0 + cast(float)G2;
            y2 := y0 + cast(float)(G2 - 1);
            a2 := (2.0 / 3.0) - x2 * x2 - y2 * y2;
            if a2 > 0 value += (a2 * a2) * (a2 * a2) * xx grad_coord_2d(seed, i, j + PRIME_Y, xx x2, xx y2);
        }
        if (yi - xmyi > 1) {
            x3 := x0 + cast(float)(3 * G2 - 1);
            y3 := y0 + cast(float)(3 * G2 - 2);
            a3 := (2.0 / 3.0) - x3 * x3 - y3 * y3;
            if a3 > 0 value += (a3 * a3) * (a3 * a3) * xx grad_coord_2d(seed, i + PRIME_X, j + (PRIME_Y << 1), xx x3, xx y3);
        } else {
            x3 := x0 + cast(float)(G2 - 1);
            y3 := y0 + cast(float)(G2);
            a3 := (2.0 / 3.0) - x3 * x3 - y3 * y3;
            if a3 > 0 value += (a3 * a3) * (a3 * a3) * xx grad_coord_2d(seed, i + PRIME_X, j, xx x3, xx y3);
        }
    } else {
        if xi + xmyi < 0 {
            x2 := x0 + cast(float)(1 - G2);
            y2 := y0 - cast(float)(G2);
            a2 := (2.0 / 3.0) - x2 * x2 - y2 * y2;
            if a2 > 0 value += (a2 * a2) * (a2 * a2) * xx grad_coord_2d(seed, i - PRIME_X, j, xx x2, xx y2);
        } else {
            x2 := x0 + cast(float)(G2 - 1);
            y2 := y0 - cast(float)(G2);
            a2 := (2.0 / 3.0) - x2 * x2 - y2 * y2;
            if a2 > 0 value += (a2 * a2) * (a2 * a2) * xx grad_coord_2d(seed, i + PRIME_X, j, xx x2, xx y2);
        }
        if yi < xmyi {
            x3 := x0 + cast(float)G2 ;
            y3 := y0 + cast(float)(G2 - 1);
            a3 := (2.0 / 3.0) - x3 * x3 - y3 * y3;
            if a3 > 0 value += (a3 * a3) * (a3 * a3) * xx grad_coord_2d(seed, i, j - PRIME_Y, xx x3, xx y3);
        } else {
            x3 := x0 + cast(float)(G2);
            y3 := y0 + cast(float)(G2 - 1);
            a3 := (2.0 / 3.0) - x3 * x3 - y3 * y3;
            if a3 > 0 value += (a3 * a3) * (a3 * a3) * xx grad_coord_2d(seed, i, j + PRIME_Y, xx x3, xx y3);
        }
    }


    return cast(float) (value * 18.24196194486065);
}

// Perlin Noise
_fnl_single_perlin_2d :: (seed : s32, x : float, y : float) -> float {
    x0 := fast_floor(x);
    y0 := fast_floor(y);

    xd0 := cast(float)(x - x0);
    yd0 := cast(float)(y - y0);
    xd1 := xd0 - 1;
    yd1 := yd0 - 1;

    xs := interp_quintic(xd0);
    ys := interp_quintic(yd0);

    x0 *= PRIME_X;
    y0 *= PRIME_Y;
    x1 := x0 + PRIME_X;
    y1 := y0 + PRIME_Y;

    xf0 := lerp(grad_coord_2d(seed, xx x0, xx y0, xd0, yd0), grad_coord_2d(seed, xx x1, xx y0, xd1, yd0), xs);
    xf1 := lerp(grad_coord_2d(seed, xx x0, xx y1, xd0, yd1), grad_coord_2d(seed, xx x1, xx y1, xd1, yd1), xs);

    return lerp(xf0, xf1, ys) * 1.4247691;
}

// Fractal FBm
gen_fractal_fbm_2d :: (using state : *FNL_State, x : float, y : float) -> float {
    sum := 0.0;
    amp := calculate_fractal_bounding(state);

    for 1..octaves {
        _seed := seed + 1;
        noise := gen_noise_single_2d(state, seed, x, y);
        sum += xx (noise * amp);
        amp *= lerp(1.0, fast_min(noise + 1, 2) * 0.5, weighted_strength);

        x *= lacunarity;
        y *= lacunarity;
        amp *= state.gain;
    }

    return sum;
}

GRADIENTS_2D : [256]float64 = 
.[
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.130526192220052, 0.99144486137381, 0.38268343236509, 0.923879532511287, 0.608761429008721, 0.793353340291235, 0.793353340291235, 0.608761429008721,
    0.923879532511287, 0.38268343236509, 0.99144486137381, 0.130526192220051, 0.99144486137381, -0.130526192220051, 0.923879532511287, -0.38268343236509,
    0.793353340291235, -0.60876142900872, 0.608761429008721, -0.793353340291235, 0.38268343236509, -0.923879532511287, 0.130526192220052, -0.99144486137381,
    -0.130526192220052, -0.99144486137381, -0.38268343236509, -0.923879532511287, -0.608761429008721, -0.793353340291235, -0.793353340291235, -0.608761429008721,
    -0.923879532511287, -0.38268343236509, -0.99144486137381, -0.130526192220052, -0.99144486137381, 0.130526192220051, -0.923879532511287, 0.38268343236509,
    -0.793353340291235, 0.608761429008721, -0.608761429008721, 0.793353340291235, -0.38268343236509, 0.923879532511287, -0.130526192220052, 0.99144486137381,
    0.38268343236509, 0.923879532511287, 0.923879532511287, 0.38268343236509, 0.923879532511287, -0.38268343236509, 0.38268343236509, -0.923879532511287,
    -0.38268343236509, -0.923879532511287, -0.923879532511287, -0.38268343236509, -0.923879532511287, 0.38268343236509, -0.38268343236509, 0.923879532511287,
];