function handle = createEllipsoid(R0,t0,param,varargin)
    % CREATEELLIPSOID
    %
    % handle = createEllipsoid(R0, t0, param,...)
    %
    % R0 is 3 x 3 matrix for orientation of the ellipsoid
    % t0 is 3 x 1 vector for center of the ellipsoid
    % param is struct containing fields
    %       radius (draws a sphere)
    %       [opt] radiusX
    %       [opt] radiusY
    %       [opt] radiusZ
    %       [opt] n     (number of points for circle discretization)
    %                       default = 12
    % possible additional properties are:
    %       'FaceColor'  default: [1;1;1]
    %       'FaceAlpha'  default: 1
    %       'LineWidth'  default: 0.5
    %       'EdgeColor'  default: [0;0;0]
    %       'EdgeAlpha'  default: 1
    %
    % returns handle to ellipsoid drawing structure
    %
    % see also CREATECUBOID CREATECYLINDER CREATEPRISM
    
    flags = {'FaceColor','FaceAlpha','LineWidth','EdgeColor','EdgeAlpha'};
    defaults = {[1;1;1], 1, 0.5, [0;0;0], 1};
    
    opt_values = mrbv_parse_input(varargin, flags, defaults);
    props = [flags;opt_values];
    
    % Verify parameters are correct
    if isfield(param,'radius')
        rx = param.radius;
        ry = param.radius;
        rz = param.radius;
    elseif isfield(param,'radiusX') && isfield(param, 'radiusY') && ...
                isfield(param,'radiusZ')
        rx = param.radiusX;
        ry = param.radiusY;
        rz = param.radiusZ;
    else
        disp('Parameterization needs either:');
        disp('    radius - for sphere');
        disp('    radiusX');
        disp('    radiusY');
        disp('    radiusZ - for ellipsoid');
        handle = [];
        return;
    end
    % resolution of points for angular discretization
    if isfield(param,'n'),   n = param.n;
    else                     n = 12;
    end
    
    % Vectices
    theta = 2*pi*(0:1/n:(n-1)/n);
    phi = pi*(0:1/n:1);
    
    X = rx*cos(theta)'*sin(phi);
    Y = ry*sin(theta)'*sin(phi);
    Z = rz*ones(n,1)*cos(phi);
    V = [X(:) Y(:) Z(:)];
    V = V*R0' + ones(length(V),1)*t0';
    
    % Faces
    F = zeros(n*n, 4);
    for i=1:n 
        for j=1:n
            F((i-1)*n+j,:) = [i*n+j, i*n+mod(j,n)+1, ...
                              (i-1)*n+mod(j,n)+1, (i-1)*n+j];
        end
    end
    
    FV.Vertices = V;
    FV.Faces = F;
    
    % To make sure the handle fields are created in a consistent order
    handle = createEmptyBody();
    
    handle.bodies = patch(FV, props{:}, 'FaceNormals',calc_normals(FV));
    handle.labels = {'sides'};
end
    