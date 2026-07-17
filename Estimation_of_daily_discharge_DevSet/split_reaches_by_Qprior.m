function segments = split_reaches_by_Qprior(Qprior, opts)
% split_reaches_by_Qprior
%
% Split one path into hydraulically more homogeneous reach segments based on
% prior discharge magnitude.
%
% Usage:
%   segments = split_reaches_by_Qprior(Qprior);
%   segments = split_reaches_by_Qprior(Qprior, opts);
%
% Output:
%   segments: nSeg x 2 matrix. Each row is [first_reach, last_reach].

if nargin < 2 || isempty(opts)
    opts = struct();
end

jump_threshold = local_getopt(opts, 'jump_threshold', 3);
max_segment_ratio = local_getopt(opts, 'max_segment_ratio', 5);
min_segment_length = local_getopt(opts, 'min_segment_length', 3);
allow_singleton_at_hard_break = local_getopt(opts, 'allow_singleton_at_hard_break', true);

Qprior = Qprior(:);
nR = numel(Qprior);

if nR == 0
    segments = zeros(0,2);
    return
end

if nR == 1
    segments = [1 1];
    return
end

Qsafe = Qprior;
Qsafe(~isfinite(Qsafe) | Qsafe <= 0) = nan;

% Hard breaks at abrupt adjacent prior discharge jumps.
jump = nan(nR-1,1);
for i = 1:nR-1
    if isfinite(Qsafe(i)) && isfinite(Qsafe(i+1))
        jump(i) = max(Qsafe(i), Qsafe(i+1)) / min(Qsafe(i), Qsafe(i+1));
    end
end

breaks = find(jump >= jump_threshold);
segments = local_segments_from_breaks(breaks, nR);

% Recursively split segments that still span too large a Qprior range.
changed = true;
while changed
    changed = false;
    new_segments = zeros(0,2);

    for iseg = 1:size(segments,1)
        r1 = segments(iseg,1);
        r2 = segments(iseg,2);
        qseg = Qsafe(r1:r2);
        qvalid = qseg(isfinite(qseg) & qseg > 0);

        if numel(qvalid) >= 2
            seg_ratio = max(qvalid) / min(qvalid);
        else
            seg_ratio = 1;
        end

        if seg_ratio > max_segment_ratio && (r2 - r1 + 1) > min_segment_length
            local_jump = jump(r1:r2-1);
            [max_jump, local_idx] = max(local_jump);

            if isfinite(max_jump)
                cut = r1 + local_idx - 1;
                left_len = cut - r1 + 1;
                right_len = r2 - cut;

                can_split = left_len >= min_segment_length && right_len >= min_segment_length;
                if ~can_split && allow_singleton_at_hard_break && max_jump >= jump_threshold
                    can_split = left_len >= 1 && right_len >= 1;
                end

                if can_split
                    new_segments = [new_segments; r1 cut; cut+1 r2]; %#ok<AGROW>
                    changed = true;
                else
                    new_segments = [new_segments; r1 r2]; %#ok<AGROW>
                end
            else
                new_segments = [new_segments; r1 r2]; %#ok<AGROW>
            end
        else
            new_segments = [new_segments; r1 r2]; %#ok<AGROW>
        end
    end

    segments = new_segments;
end

segments = local_merge_short_segments(segments, Qsafe, min_segment_length, allow_singleton_at_hard_break);

end


function segments = local_segments_from_breaks(breaks, nR)

if isempty(breaks)
    segments = [1 nR];
    return
end

starts = [1; breaks(:)+1];
ends = [breaks(:); nR];
segments = [starts, ends];

end


function segments = local_merge_short_segments(segments, Qprior, min_len, allow_singleton)

if size(segments,1) <= 1
    return
end

changed = true;
while changed
    changed = false;

    for iseg = 1:size(segments,1)
        len = segments(iseg,2) - segments(iseg,1) + 1;

        if len >= min_len
            continue
        end

        if allow_singleton && len == 1 && size(segments,1) > 1
            r = segments(iseg,1);
            prev_jump = inf;
            next_jump = inf;
            if r > 1 && isfinite(Qprior(r-1)) && isfinite(Qprior(r)) && Qprior(r-1) > 0 && Qprior(r) > 0
                prev_jump = max(Qprior(r-1), Qprior(r)) / min(Qprior(r-1), Qprior(r));
            end
            if r < numel(Qprior) && isfinite(Qprior(r+1)) && isfinite(Qprior(r)) && Qprior(r+1) > 0 && Qprior(r) > 0
                next_jump = max(Qprior(r+1), Qprior(r)) / min(Qprior(r+1), Qprior(r));
            end

            if prev_jump >= 3 && next_jump >= 3
                continue
            end
        end

        if iseg == 1
            segments(iseg+1,1) = segments(iseg,1);
            segments(iseg,:) = [];
        elseif iseg == size(segments,1)
            segments(iseg-1,2) = segments(iseg,2);
            segments(iseg,:) = [];
        else
            left_ratio = local_join_ratio(segments(iseg-1,:), segments(iseg,:), Qprior);
            right_ratio = local_join_ratio(segments(iseg,:), segments(iseg+1,:), Qprior);
            if left_ratio <= right_ratio
                segments(iseg-1,2) = segments(iseg,2);
                segments(iseg,:) = [];
            else
                segments(iseg+1,1) = segments(iseg,1);
                segments(iseg,:) = [];
            end
        end

        changed = true;
        break
    end
end

end


function ratio = local_join_ratio(seg_a, seg_b, Qprior)

idx = seg_a(1):seg_b(2);
q = Qprior(idx);
q = q(isfinite(q) & q > 0);
if numel(q) < 2
    ratio = 1;
else
    ratio = max(q) / min(q);
end

end


function v = local_getopt(opts, name, default_value)

if isfield(opts, name) && ~isempty(opts.(name))
    v = opts.(name);
else
    v = default_value;
end

end
