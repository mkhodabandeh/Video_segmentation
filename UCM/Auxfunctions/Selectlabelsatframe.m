function Selectlabelsatframe(Gif,allGis,Tm,minLength,trackLength,...
    frame,filenames,trajectories,allregionpaths,ucm2,allregionsframes,...
    flows,cim,colourratio,onwhitebase,printonscreen,firstTrajectory)


if ( (~exist('firstTrajectory','var')) || (isempty(firstTrajectory)) )
    firstTrajectory=1;
end
if ( (~exist('printonscreen','var')) || (isempty(printonscreen)) )
    printonscreen=false;
end
if ( (~exist('trackLength','var')) || (isempty(trackLength)) )
    trackLength=17;
end
if ( (~exist('minLength','var')) || (isempty(minLength)) )
    minLength=5;
end
if ( (~exist('frame','var')) || (isempty(frame)) )
    frame=40;
end

if (~(mod(trackLength,2))) %if trackLength is not a odd number
    trackLength=trackLength-1;
end
if (~(mod(minLength,2))) %if trackLength is not a odd number
    minLength=minLength-1;
end
sizeL=round( (trackLength-1)/2 );
minsizeL=round( (minLength-1)/2 );

if ( (~exist('colourratio','var')) || (isempty(colourratio)) )
    colourratio=2/3;
end
noncolourratio=1-colourratio;
if ( (~exist('onwhitebase','var')) || (isempty(onwhitebase)) )
    onwhitebase=false;
end


%determines track and dist_track_mask for visualisation
fc=frame+sizeL; %position of central frame in the sequence
fcin=sizeL+1; %position of the central frame in the longest vector (trackLength long)
%for the computation of the lowest level spanning tree (reference for region selection)
ntrackLength=minLength;
nframe=fc-minsizeL;
image=cim{nframe};
[track,mapTracToTrajectories,dist_track_mask,allDs]=...
    Prepareregiontracksandallds(image,trajectories,nframe,ntrackLength,...
    allregionpaths,ucm2,allregionsframes,flows,filenames,firstTrajectory,[],printonscreen);


%Represent computed clustering at frame
labelsfc=Turntmtolabels(Tm); %labels according to the spanning tree allGis.T (as if fully connected)
[labels,labelsv]=Getlabelsatframei(allGis,labelsfc,Gif,frame);
Representcomputedlabels(image,track,dist_track_mask,labelsv);
th=6; Representlabeledregions(image,track,dist_track_mask,labelsv,th,labelsfc);
indexframe=find(Gif.frame==frame,1); allowchanget=1;
Tmi=Turnlabelstotm(labels,Gif.Gis{indexframe}.T{1},allowchanget);
Representspanningtree(Tmi,track,dist_track_mask,image);


%For creating pixtures
figure(13), title(['Frame ',num2str(nframe)]);
% print('-depsc',['C:\Epsimages\labels',num2str(frame),'.eps']);
figure(16), title(['Frame ',num2str(nframe)]);
% print('-depsc',['C:\Epsimages\sp',num2str(frame),'.eps']);
figure(17), title(['Frame ',num2str(nframe)]);
% print('-depsc',['C:\Epsimages\lregions',num2str(frame),'.eps']);

figure(18), title(['Frame ',num2str(nframe)]);
set(gcf, 'color', 'white');
imshow(image)

if (onwhitebase)
    baseimage=ones(size(image),'uint8').*255; %a white image
else
    baseimage=image; %the original image
end
maskimage=baseimage; %a white image is coloured with selections

while (1)
    mask=false(size(dist_track_mask{1,1}));
    figure(13), title('Select a label (closest one to click in present frame)');
    [jpos,ipos]=ginput(1);
    if (isempty(ipos)||isempty(jpos))
        break;
    end
    if (  ( abs(ipos-size(image,1))<5 ) || ( abs(jpos-size(image,2))<5 )  )
        maskimage=baseimage;
        continue;
    end
    ipos=round(ipos);
    jpos=round(jpos);
    count=0;
    dist=[];
    for k=1:size(trajectories,2)
        if (isempty(trajectories{k}))
            continue;
        end
        if (trajectories{k}.totalLength<minLength)
            continue;
        end
        if ( (trajectories{k}.startFrame>nframe)||(trajectories{k}.endFrame<(nframe+minLength-1)) )
            continue;
        end
        posInarray=nframe-trajectories{k}.startFrame+1;
    %     plot(trajectories{k}.Xs(posInarray),trajectories{k}.Ys(posInarray),'+r');

        count=count+1;
        dist(count)=sqrt( (trajectories{k}.Xs(posInarray)-jpos)^2+(trajectories{k}.Ys(posInarray)-ipos)^2 );
        posInTrajArray(count)=k;
    end
    [c,r]=min(dist);
    k=posInTrajArray(r);
    fprintf('Trajectory number of the selected = %d\n',k);
    % nopath=trajectories{k}.nopath;
    % region=Lookupregioninallregionpaths(allregionpaths,nframe,nopath);
    % level=allregionsframes{nframe}{region}.ll(1,1);
    % label=allregionsframes{nframe}{region}.ll(1,2);
    % mappednopath=correspondentPath{nframe}{level}(label);
    % if (exist('cim','var')&&exist('mapPathToTrajectory','var')) %shows region on the image
    %     Graphicregionpathsandtrajectories(mappednopath,ucm2,correspondentPath,allregionsframes,allregionpaths,trajectories,mapPathToTrajectory,cim);
    % elseif (exist('cim','var'))
    %     Graphicalcorrespondentpath(mappednopath,ucm2,correspondentPath,cim);
    % else %shows region mask
    %     Graphicalcorrespondentpath(mappednopath,ucm2,correspondentPath);
    % end

    rr=find(mapTracToTrajectories==k,1);
    if (isempty(rr))
        fprintf('Correspondences discarded\n');
        continue;
    end
    fprintf('Track number of the selected = %d\n',rr);

    selectedlabel=labelsv(rr);
%     selectedtracks=find(labelsv==repmat(selectedlabel,size(labelsv)));
    selectedtracks=find(labelsv==selectedlabel);
    col=uint8(round(GiveDifferentColours(selectedlabel)*255*colourratio));

    fprintf('Label selected = %d, no regions at the frame = %d',selectedlabel,numel(selectedtracks));
    fprintf(', no regions in video = %d\n',sum(labelsfc==selectedlabel));
    
    for j=selectedtracks
    % dist_track_mask{which frame,which trajectory}=mask
        mask=mask|dist_track_mask{1,j};
    end

    cparttocolour=cat(3,mask,mask,mask);
    
    colourtogive=cat(3,repmat(col(1),size(mask)),repmat(col(2),size(mask)),repmat(col(3),size(mask)));
    maskimage(cparttocolour)=uint8(round(image(cparttocolour)*noncolourratio))+colourtogive(cparttocolour);
    
%     maskimage(cparttocolour)=image(cparttocolour); %subtracting only blue makes the marked regions yellow
    
    figure(20), title(['Frame ',num2str(nframe)]);
    set(gcf, 'color', 'white');
    imshow(maskimage)

    pause(3);
end







