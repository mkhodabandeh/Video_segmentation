function [mappedX,lambda,L]=Getnewlaplacian(W,dimtouse,methodofchoice,optslaplsolver,printonscreen)
%The output mappedX contains dimtouse dimensional points (eigenvector
%corresponding to 0 eigevalue included) which correspond to values in lambda
%W is the similarities matrix
%The function may be tested on toy cases (Testtoycase.m, Test_equiv_case.m)
%mappedX = [ no_data_points x dimtouse ]
%lambda = [ dimtouse x 1 ]
%
%required files: components.m, jdqz.m
%
%This version (compare with Newlaplacian.m) includes the first eigenvector among the first dimtouse



if ( (~exist('dimtouse','var')) || (isempty(dimtouse)) )
    dimtouse=6;
end
if ( (~exist('methodofchoice','var')) || (isempty(methodofchoice)) )
    methodofchoice=3;
end
if ( (~exist('printonscreen','var')) || (isempty(printonscreen)) )
    printonscreen=false;
end
if ( (~exist('optslaplsolver','var')) || (isempty(optslaplsolver)) )
    optslaplsolver.disp = 0;
    optslaplsolver.isreal = 1;
    optslaplsolver.issym = 1;
end



nnodes=size(W,1);


if (dimtouse>(nnodes))
    dimtouse=(nnodes);
    fprintf('Set dimtouse to %d\n',dimtouse);
end



% Construct diagonal matrix with volumes
dvalues=full(sum(W, 2)); %size(dvalues)
DD = spdiags(dvalues,0,nnodes,nnodes);
% DD = diag(sum(W, 2));



%Check for Nan values in W
if ( (any(isnan(dvalues))) || (any(isinf(dvalues))) )
    error('NaN or Inf values in W');
end



if (max(max(W-W'))>(10^(-6))) %(~isequal(W,W'))
    fprintf('Non-symmetric matrix\n');
    optslaplsolver.issym = 0;
    if (methodofchoice~=5)
        fprintf('Current laplacian method %d, adopting method 5 for non-symmetric matrices\n',methodofchoice);
        methodofchoice=5;
    end
end



if (issparse(W))
    isitsparse=true;
else
    fprintf('Non-sparse matrix\n');
    isitsparse=false;
    if ( (methodofchoice~=1) && (methodofchoice~=5) )
        fprintf('Non sparse matrices should specify methods 1 and 5, adopting method 1\n');
        methodofchoice=1;
    end
end



switch(methodofchoice)
    case 1 %%%Solve the generalized eigenvalue problem
        
        %Compute unnormalized laplacian
        L = DD - W;

        %Compute the generalized eigenvalue problem L*v=lambda*DD*v equivalent to eigendecomposing DD^(-1)*L
        if (isitsparse)
            try
                [mappedX, lambda] = eigs(L, DD, dimtouse, 'sa' , optslaplsolver);            % only need bottom (dimtouse) eigenvectors
            catch ME %#ok<NASGU>
                [mappedX, lambda] = eigs(L, DD, dimtouse, 'sr' , optslaplsolver);            % only need bottom (dimtouse) eigenvectors
                fprintf('Method sa did not produce a solution, trying sr instead\n');
            end
        else
            [mappedX, lambda] = eig(L, DD); %'qz' optional flag used for asymmetric matrices
        end
        %mappedX is no_data_points x dimtouse

    case 2 %%% Solve with method of Ng and Jordan using symmetric normalization and eigenvector re-normalization
        
        % Compute symmetrically normalized Laplacian
        DDminushalf = spdiags(sqrt(1./dvalues),0,nnodes,nnodes);
        L=speye(nnodes)-DDminushalf*W*DDminushalf;
        % DDminushalf=sqrt(DD^(-1));

        
        if (isitsparse)
            tol = 0;
            [mappedX, lambda] = eigs(L, dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
            % [U,lambda,mappedX]=svds(L, dimtouse, tol, optslaplsolver);
        else
            %In the non-generalized eig decomposition the flag 'qz' is not an accepted option
            [mappedX, lambda] = eig(L,'nobalance'); %'nobalance' is neglected for symmetric matrices
        end
        %Transform the eigenvectors to those obtained with methods 1 and 3 (generalized eigenvalue problem)
        % mappedX=DDminushalf*mappedX; %Port eigenvectors to the corresponding from the non-symmetrically normalized Laplacian
                                       %Von Luxburg: eigenspace spanned by DDminushalf*eigenvetors (not piecewise constant)
        %mappedX is no_data_points x dimtouse
        
        %Normalize the eigenvectors to norm 1 (the columns of mappedX)
        mappedX=mappedX./repmat(sqrt(sum(mappedX.^2,1)),size(mappedX,1),1);

        %Normalize the rows of mappedX (the data point coordinates on the manifold) to 1
        mappedX=mappedX./repmat( sqrt(sum(mappedX.^2,2)) , 1 , size(mappedX,2) );
        
    case 3 %%%Solve the generalized eigenvalue problem

        %Asymmetric normalization
        L = DD - W;

        %Compute the generalized eigenvalue problem L*v=lambda*DD*v equivalent to eigendecomposing DD^(-1)*L
        tol = 0;
        try [mappedX, lambda] = eigs(L, DD, dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
        catch ME1, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, adding eps to the diagonal matrix and trying again\n \n\n\n\n\n\n'); %#ok<NASGU>
            try [mappedX, lambda] = eigs(L, DD+10*eps*speye(size(DD)), dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
            catch ME2, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, adding eps to the diagonal of the Laplacian and trying again\n \n\n\n\n\n\n'); %#ok<NASGU>
                try [mappedX, lambda] = eigs(L+10*eps*speye(size(L)), DD, dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
                catch ME3, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, adding eps to the diagonal of the Laplacian and to the diagonal matrix and trying again\n \n\n\n\n\n\n'); %#ok<NASGU>
                    try [mappedX, lambda] = eigs(L+10*eps*speye(size(L)), DD+10*eps*speye(size(DD)), dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
                    catch ME4, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, trying again with sa\n \n\n\n\n\n\n'); %#ok<NASGU>
                        try [mappedX, lambda] = eigs(L, DD, dimtouse, 'sa' , optslaplsolver);            % only need bottom (dimtouse) eigenvectors
                        catch ME5, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, trying again with sr\n \n\n\n\n\n\n'); %#ok<NASGU>
                            try [mappedX, lambda] = eigs(L, DD, dimtouse, 'sr' , optslaplsolver);            % only need bottom (dimtouse) eigenvectors
                            catch ME6, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, trying again with sm\n \n\n\n\n\n\n'); %#ok<NASGU>
                                try [mappedX, lambda] = eigs(L, DD, dimtouse, 'sm' , optslaplsolver);            % only need bottom (dimtouse) eigenvectors
                                catch ME7, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, adding 0.01 to the diagonal matrix and trying again\n \n\n\n\n\n\n'); %#ok<NASGU>
                                    try [mappedX, lambda] = eigs(L, DD+0.01*speye(size(DD)), dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
                                    catch ME8, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, adding 0.01 to the diagonal of the Laplacian and trying again\n \n\n\n\n\n\n'); %#ok<NASGU>
                                        try [mappedX, lambda] = eigs(L+0.01*speye(size(L)), DD, dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
                                        catch ME9, fprintf('\n\n\n\n\n\nEigendecomposition could not be computed, adding 0.01 to the diagonal of the Laplacian and to the diagonal matrix and trying again\n \n\n\n\n\n\n'); %#ok<NASGU>
                                            [mappedX, lambda] = eigs(L+0.01*speye(size(L)), DD+0.01*speye(size(DD)), dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        %mappedX is no_data_points x dimtouse
        
    case 4 %%% Solve generalized Schur decomposition

        L = DD - W;
        
        optslaplsolver.Disp = 0;
        optslaplsolver.LSolver = 'bicgstab';
        tol = 0;
        [mappedX, lambda] = jdqz(L, DD, dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
        %mappedX is no_data_points x dimtouse

    case 5 %%%Solve with symmetrically normalized Laplacian and map eigenvectors to solution from non-symmetrically normalized Laplacian
        
        % Compute symmetrically normalized Laplacian
        DDminushalf = spdiags(sqrt(1./dvalues),0,nnodes,nnodes);
        L=speye(nnodes)-DDminushalf*W*DDminushalf;
        % DDminushalf=sqrt(DD^(-1));

        
        if (isitsparse)
            tol = 0;
            [mappedX, lambda] = eigs(L, dimtouse, tol, optslaplsolver);			% only need bottom (dimtouse) eigenvectors
            % [U,lambda,mappedX]=svds(L, dimtouse, tol, optslaplsolver);
        else
            %In the non-generalized eig decomposition the flag 'qz' is not an accepted option
            [mappedX, lambda] = eig(L,'nobalance'); %'nobalance' is neglected for symmetric matrices
        end
        %Transform the eigenvectors to those obtained with methods 1 and 3 (generalized eigenvalue problem)
        mappedX=DDminushalf*mappedX; %Port eigenvectors to the corresponding from the non-symmetrically normalized Laplacian
                                     %Von Luxburg: eigenspace spanned by DDminushalf*eigenvetors (not piecewise constant)
        %mappedX is no_data_points x dimtouse
        
    otherwise
        error('Unrecognized method');
end

%Compute norms of eigenvectors
eigenvectornorms=sqrt(sum(mappedX.^2,1))';



%Convert matrix to vector of eigenvalues
lambda=diag(lambda);



%Check that eigenvalues are real
if (any(~isreal(lambda)))
    fprintf('\n\n\n\n\nSome of the computed eigenvalues are complex, taking the real part\n\n\n\n\n\n');
    lambda=real(lambda);
end



%Change sign to negative eigenvalue-corresponding eigenvector
lambdaminus=(lambda<0);
mappedX(:,lambdaminus)= (-mappedX(:,lambdaminus));
lambda(lambdaminus)= (-lambda(lambdaminus));



%Selection of first dimtouse eigenvectors (first is included into count)
[lambda, ind] = sort(lambda, 'ascend');
fprintf('First %d eigenvalues including first (eigenvector norm):',dimtouse); fprintf(' %f (%f)',[lambda,eigenvectornorms]'); fprintf('\n'); %mappedX(:,1)
mappedX = mappedX(:,ind);
%In the case of Ng and Jordan all mappedX should be returned, as the first
%value is not any more constant



if (printonscreen)
    Init_figure_no(5), plot(lambda,'*');
end
if (printonscreen)
    minvectors=min(mappedX,[],1);
    fprintf('Min of eigenvectors(dim): ');fprintf(' %10f(%d)',[minvectors;1:max(dimtouse)]);fprintf('\n');
    maxvectors=max(mappedX,[],1);
    fprintf('Max of eigenvectors(dim): ');fprintf(' %10f(%d)',[maxvectors;1:max(dimtouse)]);fprintf('\n');
    vectornorms=sum(abs(mappedX).^2,1).^(1/2);
    fprintf('Norms of eigenvectors(dim):');fprintf(' %10f(%d)',[vectornorms;1:max(dimtouse)]);fprintf('\n');
    vectorvar=var(mappedX,1);
    fprintf('Norms of eigenvectors(dim):');fprintf(' %10e(%d)',[vectorvar;1:max(dimtouse)]);fprintf('\n');
end



%Normalize of eigenvectors to norm 1 (the columns of mappedX)
% mappedX=mappedX./repmat(sqrt(sum(mappedX.^2,1)),size(mappedX,1),1);

%Normalize all eigenvectors to [0,1] (the columns of mappedX)
% mappedX= ( mappedX-repmat(min(mappedX,[],1),size(mappedX,1),1) ) ./...
%     repmat(max(mappedX,[],1)-min(mappedX,[],1),size(mappedX,1),1) ;

%Normalize the rows of mappedX (the data point coordinates on the manifold) to 1
% mappedX=mappedX./repmat( sqrt(sum(mappedX.^2,2)) , 1 , size(mappedX,2) );





function Test_this_function()

AAA=[0,1,0.5;1,0,0.3;0.5,0.3,0];
AAA=[0,1,0.5;1,0,0.3;0.49,0.3,0]; %asymmetric matrix
methodofchoice=3;

[mappedX,lambda]=Newlaplacian(sparse(AAA),size(AAA,1)-1,methodofchoice) %,L

[mappedX,lambda]=Newlaplacian(AAA,size(AAA,1)-1,methodofchoice) %,L

% neigtest=2;
% disp (  (L*mappedX(:,neigtest-1)/lambda(neigtest))  ...
% ./mappedX(:,neigtest-1)  )

% norm(mappedX)
