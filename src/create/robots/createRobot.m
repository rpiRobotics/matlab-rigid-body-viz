function handle = createRobot(robot, varargin)
    % CREATEROBOT 
    %
    % handle = createRobot(robot, ...)
    %
    % purpose: creates a robot drawing object in zero configuration
    %
    % input:
    % standard robot definition struct with fields:
    %   name: string denoting the name of the robot
    %   kin:
    %       H: [ h_1 h_2 ... h_n ] actuation axis for each joint
    %       P: [ p_{O,1} p_{1,2} .. p_{n-1,n} p_{n,T] inter-joint vectors
    %       joint_type:     0 = rotational  
    %                       1 = prismatic 
    %                       2 = rotational (non-visible) 
    %                       3 = translational (non-visible)
    %   vis:
    %       joints: n dimensional struct array with fields
    %              param: parameterization according to joint_type
    %              props: visual properties
    %       links: (n + 1) dimensional struct array with fields
    %              handle:  function handle to object / primitive
    %              R:       orientation from base drawing frame
    %              t:       displacement from frame to origin of object
    %              param:   parameterization according to handle
    %              props:   visual properties
    %               ** If no link is to be drawn, leave handle empty **
    %       frame: single struct describing coordinate frames
    %       peripherals: arbitrary length struct array with fields
    %              id:      string id for peripheral
    %              frame:   frame index this peripheral is attached to
    %              handle:  function handle to object / primitive
    %              R:       orientation from base drawing frame
    %              t:       displacement from frame to origin of object
    %              param:   parameterization according to handle
    %              props:   visual properties
    %
    % Optional Additional Properties:
    %       'CreateFrames'          default: 'off'
    % 
    % depends on the following drawing package files:
    %       createCuboid.m
    %       createCylinder.m
    %       create3DFrame.m
    %       attachPrefix.m
    %
    % returns handle to robot drawing object
    %
    % see also UPDATEROBOT CREATE3DFRAME

    flags = {'CreateFrames'};
    defaults = {'off'};
    
    opt_values = mrbv_parse_input(varargin, flags, defaults);
    cf = opt_values{1};
        
    % Normal orientation for actuation axis on primitive shapes
    z0 = [0;0;1];
    
    % Initialize components so that structure can be treated as a 'rigid
    % body' in other functions.
    handle = createEmptyBody();
    % Build structure for 'robots' field within the rigid body and set
    % initial values / placeholders
    handle.robots = struct( ...
            'name',      robot.name, ...
            'kin',       robot.kin, ...
            'frames',    struct('bodies',[],'R',eye(3),'t',[0;0;0]), ...
            'base',      struct('bodies',[],'R',eye(3),'t',[0;0;0]), ...
            'load',      [], ...
            'left',      'root', ...
            'right',     {{}});
    
    % Add field in the kinematics field to store the current state and
    % initialize to all zeros
    handle.robots.kin.state = zeros(size(robot.kin.joint_type));
    
    % Counter for the number of bodies
    n_bodies = 0;
    
    % Create link p_{O,1} and attach to base
    if ~isempty(robot.vis.links(1).handle)
        Ri = robot.vis.links(1).R;
        ti = robot.vis.links(1).t;
        link = robot.vis.links(1).handle(Ri, ti, ...
                                    robot.vis.links(1).param, ...
                                    robot.vis.links(1).props{:});
    else
        link.bodies = [];
        link.labels = {};
    end
    
    % Add bodies/labels to master list
    handle.bodies = [handle.bodies link.bodies];
    handle.labels = [handle.labels ...
                attachPrefix([handle.robots.name '_base_'], link.labels)];
    % Add references within the 'base' frame
    handle.robots.base.bodies = 1:numel(link.bodies);
    % Increment body count
    n_bodies = n_bodies + numel(link.bodies);
        
    % Pre-compute positions of all joint frames in zero pose
    P = cumsum(handle.robots.kin.P,2);
    p = P(:,1);
    R = eye(3); 
    
    % Fill the terms relating bodies to each frame within the robot
    for i=1:length(handle.robots.kin.joint_type)
        
        % Update the frame position and orientation
        handle.robots.frames(i).R = eye(3);
        handle.robots.frames(i).t = p;
        
        % Create joint i
        h = handle.robots.kin.H(:,i);
        if (abs(z0'*h)==1), Ri = eye(3);
        else                Ri = rot(hat(z0)*h, acos(h(3)));
        end
        
        joint_name = [handle.robots.name '_joint' num2str(i) '_'];
        if handle.robots.kin.joint_type(i) == 0  % rotational
            
            joint = createCylinder(Ri, p, robot.vis.joints(i).param, ...
                                    robot.vis.joints(i).props{:});
            % Add bodies/labels to master list
            handle.bodies = [handle.bodies joint.bodies];
            handle.labels = [handle.labels ...
                    attachPrefix(joint_name, joint.labels)];
            % Add pointers to body indices in the frame subfield
            handle.robots.frames(i).bodies = ...
                                    n_bodies + (1:numel(joint.bodies));
            n_bodies = n_bodies + numel(joint.bodies);
            
        elseif handle.robots.kin.joint_type(i) == 1  % prismatic
            
            joint = createPrismaticJoint(Ri, p, robot.vis.joints(i).param, ...
                                    robot.vis.joints(i).props{:});
            % Add bodies/labels to master list
            handle.bodies = [handle.bodies joint.bodies];
            handle.labels = [handle.labels ...
                    attachPrefix(joint_name, joint.labels)];
            
            % Add pointers to body indices in the frame subfield
            % for prismatic, associate base with prior frame
            if (i > 1)
                handle.robots.frames(i-1).bodies = ...
                        [handle.robots.frames(i-1).bodies, n_bodies + 1];
            else
                handle.robots.base.bodies = ...
                        [handle.robots.base.bodies, n_bodies + 1];
            end
            handle.robots.frames(i).bodies = n_bodies + 2;
            n_bodies = n_bodies + numel(joint.bodies);
            
        elseif any(handle.robots.kin.joint_type(i) == [2 3]) % mobile
            handle.robots.frames(i).bodies = [];
        end
        
        % If drawing coordinate frames, draw one at joint i
        %   Do not draw 'mobile' joint coordinate frames
        if strcmpi(cf,'on') && ~any(handle.robots.kin.joint_type(i) == [2 3])
            frame = create3DFrame(R, p, robot.vis.frame);
            % Add bodies/labels to master list
            frame_name = [handle.robots.name '_frame' num2str(i) '_'];
            handle.bodies = [handle.bodies frame.bodies];
            handle.labels = [handle.labels ...
                            attachPrefix(frame_name, frame.labels)];
            % Add pointers to body indices in the frame subfield
            handle.robots.frames(i).bodies = ...
                        [handle.robots.frames(i).bodies ...
                        n_bodies + (1:numel(frame.bodies))];
            n_bodies = n_bodies + numel(frame.bodies);
        end
        
        % Create link p_{i,i+1}, if specified
        if ~isempty(robot.vis.links(i+1).handle)
            Ri = R*robot.vis.links(i+1).R;
            ti = p + R*robot.vis.links(i+1).t;
            
            link = robot.vis.links(i+1).handle(Ri, ti, ...
                                    robot.vis.links(i+1).param, ...
                                    robot.vis.links(i+1).props{:});
        else
            link.bodies = [];
            link.labels = {};
        end
        % Add bodies/labels to master list
        link_name = [handle.robots.name '_link' num2str(i) '_'];
        
        handle.bodies = [handle.bodies link.bodies];
        handle.labels = [handle.labels ...
                            attachPrefix(link_name , link.labels)];
        % Add pointers to body indices in the frame subfield
        handle.robots.frames(i).bodies = ...
                    [handle.robots.frames(i).bodies ...
                    n_bodies + (1:numel(link.bodies))];
        n_bodies = n_bodies + numel(link.bodies);
        
        % Pre-computed forward kinematics
        p = P(:,i+1);
    end
    
    nj = length(handle.robots.kin.joint_type);
    
    % Add final frame at O_T
    handle.robots.frames(nj+1).bodies = [];
    handle.robots.frames(nj+1).R = eye(3);
    handle.robots.frames(nj+1).t = p;
    
    % If drawing coordinate frames, draw one at position O_T
    if strcmpi(cf,'on')
        frame = create3DFrame(R, p, robot.vis.frame);
        % Add bodies/labels to master list
        frame_name = [handle.robots.name '_frameT_'];
        handle.bodies = [handle.bodies frame.bodies];
        handle.labels = [handle.labels ...
                    attachPrefix(frame_name, frame.labels)];
        % Add pointers to body indices in the frame subfield
        handle.robots.frames(nj+1).bodies = ...
                    [handle.robots.frames(nj+1).bodies ...
                    n_bodies + (1:numel(frame.bodies))];
        
        n_bodies = n_bodies + numel(frame.bodies);
    end
    
    % Attach peripherals to robot in prescribed position
    for n = 1:numel(robot.vis.peripherals)
        % Get relative coordinate frame for peripheral to attach to
        if isnumeric(robot.vis.peripherals(n).frame)
            i = robot.vis.peripherals(n).frame;
            Ri = handle.robots.frames(i).R;
            ti = handle.robots.frames(i).t;
        elseif strcmp(robot.vis.peripherals(n).frame,'tool')
            i = nj + 1;
            Ri = handle.robots.frames(i).R;
            ti = handle.robots.frames(i).t;
        elseif strcmp(robot.vis.peripherals(n).frame,'base')
            i = 0;
            Ri = eye(3);
            ti = [0;0;0];
        end

        Rp = Ri*robot.vis.peripherals(n).R;
        tp = ti + Ri*robot.vis.peripherals(n).t;

        periph = robot.vis.peripherals(n).handle(Rp, tp, ...
                            robot.vis.peripherals(n).param, ...
                            robot.vis.peripherals(n).props{:});
        % Add bodies/labels to master list
        periph_name = [handle.robots.name '_' ...
                        robot.vis.peripherals(n).id '_'];
        handle.bodies = [handle.bodies periph.bodies];
        handle.labels = [handle.labels ...
                    attachPrefix(periph_name, periph.labels)];
        % Add pointers to body indices in the frame subfield
        if i == 0
            handle.robots.base.bodies = ...
                        [handle.robots.base.bodies ...
                        n_bodies + (1:numel(periph.bodies))];
        else
            handle.robots.frames(i).bodies = ...
                        [handle.robots.frames(i).bodies ...
                        n_bodies + (1:numel(periph.bodies))];
        end
        n_bodies = n_bodies + numel(periph.bodies);
    end
        
end