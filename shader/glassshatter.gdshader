shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform vec2 click_position = vec2(0.0, 0.0);
uniform bool show_crack = false;
uniform float crack_thickness = 0.25;
uniform int point_count = 30;
uniform float crack_intensity = 1.0;

uniform float refraction_strength = 5.0;
uniform float blur_amount = 2.0;
uniform float glass_tint = 0.1;
uniform float crack_glow = 0.5;

uniform vec4 crack_color : source_color = vec4(0.118, 0.118, 0.118, 0.588);
uniform float heal_amount = 0.0;

// random
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

// noise
float noise(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// voronoi edge
float voronoi_edge(vec2 uv, int count, out float min_dist, out float second_dist, out vec2 nearest_point) {
    min_dist = 1000.0;
    second_dist = 1000.0;
    nearest_point = uv;

    for (int i = 0; i < 50; i++) {
        if (i >= count) break;

        float t = float(i) / float(count - 1);
        float max_radius = 500.0;
        float r = max_radius * pow(t, 1.2);

        float angle = random(vec2(float(i), click_position.x + click_position.y)) * 6.28318;
        angle += noise(vec2(float(i) * 0.1, 0.0)) * 1.0;

        vec2 point = click_position + vec2(cos(angle), sin(angle)) * r;

        float dist = distance(uv, point);

        if (dist < min_dist) {
            second_dist = min_dist;
            min_dist = dist;
            nearest_point = point;
        } else if (dist < second_dist) {
            second_dist = dist;
        }
    }

    return second_dist - min_dist;
}

void fragment() {
    vec2 uv = FRAGCOORD.xy;
    vec2 screen_uv = SCREEN_UV;
    
    // --- BASE GLASS EFFECT (applies to entire glass surface) ---
    // Add subtle constant refraction to whole glass
    vec2 base_refraction = vec2(
        noise(uv * 0.01) * 0.0005,
        noise(uv * 0.01 + 100.0) * 0.0005
    );
    
    vec2 glass_uv = screen_uv + base_refraction;
    vec4 glass_color = texture(SCREEN_TEXTURE, glass_uv);
    
    // Add subtle blur to entire glass
    vec4 blur_col = vec4(0.0);
    float total = 0.0;
    int samples = 1; // Light blur on whole glass
    for (int x = -samples; x <= samples; x++) {
        for (int y = -samples; y <= samples; y++) {
            vec2 offset = vec2(float(x), float(y)) * 0.0005;
            blur_col += texture(SCREEN_TEXTURE, glass_uv + offset);
            total += 1.0;
        }
    }
    blur_col /= total;
    
    // Apply glass tint to entire surface
    glass_color = mix(blur_col, vec4(0.8, 0.9, 1.0, 1.0), glass_tint * 0.5);
    
    // --- CRACK EFFECT (only if showing) ---
    if (show_crack) {
        float min_dist, second_dist;
        vec2 nearest_point;

        float edge_value = voronoi_edge(uv, point_count, min_dist, second_dist, nearest_point);

        float is_edge = 1.0 - smoothstep(0.0, crack_thickness, edge_value);

        float crack_noise = noise(uv * 0.05) * 0.2;
        is_edge = clamp(is_edge + crack_noise * 0.1, 0.0, 1.0);

        // Apply healing
        float heal_factor = 1.0 - heal_amount;
        is_edge = is_edge * heal_factor;
        
        float dissolve = smoothstep(heal_amount - 0.2, heal_amount + 0.3, is_edge);
        
        vec2 shard_dir = normalize(uv - nearest_point);
        float shard_strength = 1.0 - smoothstep(0.0, 250.0, min_dist);
        
        // Enhanced refraction near cracks
        float current_refraction = refraction_strength * (1.0 - heal_amount * 0.8);

        vec2 magnify = (uv - nearest_point) * 0.0008 * shard_strength;

        vec2 refracted_uv = screen_uv
            + shard_dir * current_refraction * 0.001 * shard_strength
            + magnify;

        // Stronger blur near cracks
        vec4 crack_blur = vec4(0.0);
        float crack_total = 0.0;
        int crack_samples = int(blur_amount);
        for (int x = -crack_samples; x <= crack_samples; x++) {
            for (int y = -crack_samples; y <= crack_samples; y++) {
                vec2 offset = vec2(float(x), float(y)) * 0.001;
                crack_blur += texture(SCREEN_TEXTURE, refracted_uv + offset);
                crack_total += 1.0;
            }
        }
        crack_blur /= crack_total;
        crack_blur = mix(crack_blur, vec4(0.8, 0.9, 1.0, 1.0), glass_tint);

        // Mix between base glass and crack effect based on distance to crack
        float mix_factor = smoothstep(0.0, 150.0, min_dist);
        mix_factor = 1.0 - mix_factor;
        mix_factor = mix_factor * (1.0 - heal_amount);
        
        glass_color = mix(glass_color, crack_blur, mix_factor);

        // Crack glow
        float glow = is_edge * crack_glow * crack_intensity * (1.0 - heal_amount);
        float dist_center = distance(uv, click_position);
        float inner_glow = (1.0 - smoothstep(0.0, 80.0, dist_center)) * 0.3 * (1.0 - heal_amount);
        float crack_light = glow + inner_glow;

        glass_color.rgb += crack_color.rgb * crack_light;
        
        if (dissolve < 0.1) {
            // Keep base glass effect even when crack is healing
            glass_color = mix(glass_color, glass_color, 0.0);
        }
    }

    COLOR = vec4(glass_color.rgb, 1.0);
}