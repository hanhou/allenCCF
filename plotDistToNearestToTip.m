function borders = plotDistToNearestToTip(m, p, av, st, rpl, error_length, active_site_start, probage_past_tip_to_plot)


% these are the query points along the probe tract
yc = 10*[0:(rpl + probage_past_tip_to_plot*100 -1)] - 20;
t = yc/10; % dividing by 10 accounts for the 10um resolution of the atlas
x = m(1)+p(1)*t;
y = m(2)+p(2)*t;
z = m(3)+p(3)*t;
ortho_plane = null(p);

projection_matrix = ortho_plane * ortho_plane'; % projection matrix onto plane orthogonal to probe tract
scaling_factor = sin(atan2(norm(cross(p,[1 0 1])), dot(p,[1 0 1]))); % sin of angle between x-z plane and probe tract

% plot labelled probe tract
fD = figure('Name','Probe Tract','Position',[1200 -200 250 900]);
box off;

for ann_type = 1:2 % loop between specific and parent region annotations
    
% collect annotations along the track
annotation_square = ones(size(t,1), error_length*2+1, error_length*2+1);
ann = ones(1,size(t,1));
cm = zeros(numel(t),3);
allenCmap = allen_ccf_colormap();

inds = -error_length:error_length;
dists = (inds.^2+inds'.^2).^(0.5);
dists = dists(:);
[dists, distOrder] = sort(dists);
otherDist = zeros(numel(t),1);
for ind = 1:length(t)
    if x(ind)>0 && x(ind)<=size(av,1) &&...
       y(ind)>0 && y(ind)<=size(av,2) &&...
       z(ind)>0 && z(ind)<=size(av,3)
   
        % add annotation to list of annotations
        if ann_type == 1
            ann(ind) = av(ceil(x(ind)), ceil(y(ind)), ceil(z(ind)));
            cm(ind,:) = allenCmap(ann(ind),:);    % also add color map?         
        elseif ann_type == 2
            ann(ind) = st(av(ceil(x(ind)), ceil(y(ind)), ceil(z(ind))),:).parent_structure_id; % get annotation for parent region
        end
        
        % go in square orthogonal to probe tract and get other regions
        for index1 = -error_length:error_length
            for index2 = -error_length:error_length
              % get index of square index projected onto plane orthogonal to probe  
              project_index_onto_ortho_plane = round(projection_matrix * [index1 0 index2]' / scaling_factor);
              % use this index and register its annotation
              annotation_square(ind,error_length+1+index1,error_length+1+index2) = av(ceil(x(ind)+project_index_onto_ortho_plane(1)), ...
                                                          ceil(y(ind)+project_index_onto_ortho_plane(2)), ...
                                                          ceil(z(ind)+project_index_onto_ortho_plane(3)));
            end
        end
                                                  
        cur_annotation_square = squeeze(annotation_square(ind,:,:));

        currSqVec = cur_annotation_square(:);
        otherInd = find(currSqVec(distOrder)~=currSqVec(distOrder(1)),1); 
        if isempty(otherInd)
            otherDist(ind) = dists(end);
        else
            otherDist(ind) = dists(otherInd);
        end


    end
end


if ann_type == 1
    uAnn = unique(ann);
    nC = numel(unique(ann(ann>1)));
    distinctCmap = distinguishable_colors(nC);

    if any(uAnn==1)
        distinctCmap = vertcat([1 1 1], distinctCmap); % always make white be ann==1, outside the brain
    end
    dc = zeros(max(uAnn),3); dc(uAnn,:) = distinctCmap;
    cmD = dc(ann,:)*.8;
end

% algorithm for finding areas and labels
region_borders = [0; find(diff(ann)~=0)'; length(yc)]';
if ann_type == 1
    midY = zeros(numel(region_borders)-1 - logical( sum(region_borders==round(rpl)) ) - logical(sum(region_borders==round(active_site_start))) ,1);
    acr = {}; 
    shift_ind = 0;
end


% add active site start and rpl as pseudo-borders
if active_site_start
    if ~sum(region_borders==round(active_site_start))
        region_borders = [region_borders(1:max(find(region_borders<active_site_start)) ) round(active_site_start)  ...
            region_borders(max(find(region_borders<active_site_start))+1:end)];
        active_site_start_is_boundary = 0;
    else
        active_site_start_is_boundary = 1;
    end
    if ~sum(region_borders==round(rpl))
        region_borders = [region_borders(1:find(region_borders>rpl,1)-1) round(rpl) region_borders(find(region_borders>rpl,1):end)];
        probe_tip_is_boundary = 0;
    else
        probe_tip_is_boundary = 1;
    end
else; 
end
borders = region_borders;




for b = 1:length(borders)-1    
    
    ycInds = (borders(b):min(borders(b+1)-1, length(yc)))+1;
    theseYC = yc(ycInds);
    
    try
    if max(theseYC) < active_site_start*10  || max(theseYC) > rpl*10
        cur_alpha = .5;
    else
        cur_alpha = 1;
    end   
    catch
        disp('null');
    end
    
    fill([0 0 otherDist(ycInds)'*10],...
        [max(theseYC) min(theseYC) theseYC], cmD(borders(b)+1,:),...
        'EdgeAlpha', 0, 'FaceAlpha', cur_alpha); 
    hold on;

    if ann_type==1
        if (borders(b+1) == round(active_site_start) && ~active_site_start_is_boundary) || ( (borders(b) == round(rpl)) && ~probe_tip_is_boundary)
     	  shift_ind = shift_ind + 1;
        else
            midY(b - shift_ind) = mean(theseYC);
            acr{b - shift_ind} = st.acronym{ann(borders(b)+1)};
            name{b - shift_ind} = st.safe_name{ann(borders(b)+1)};
            annBySegment(b - shift_ind) = ann(borders(b)+1);            
        end
    end
end
end
% borders = table(yc(borders(2:end-1))', yc(borders(3:end))', acr(2:end)', name(2:end)', annBySegment(2:end)', ...
%     'VariableNames', {'upperBorder', 'lowerBorder', 'acronym', 'name', 'avIndex'})
set(gca, 'YTick', midY, 'YTickLabel', acr);
set(gca, 'YDir','reverse');
xlabel('dist to nearest');
ylim([0 yc(borders(end-1))])
xlim([0 error_length*10]);
box off;

